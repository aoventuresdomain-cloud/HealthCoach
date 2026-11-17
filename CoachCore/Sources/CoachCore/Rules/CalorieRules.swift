import Foundation

// Board M4-01: calories from the 7-day weight trend, within safe bounds.
// Numbers are the Advisor's ruling of 17 Nov 2026 (docs/coach.md). The engine
// is stateless: it replays every weekly check from the programme start, from
// the weigh-ins and the accepted Claude blocks, so nothing but those is stored.

/// The bounds and steps the calorie engine works within.
public enum CalorieRules {
    /// Phase 1 starts here (plan §2: ~2,000 kcal).
    public static let startKcal = 2_000
    /// Daily protein target (plan §2).
    public static let proteinG = 160
    /// Cut phases never go outside this, whatever the trend says.
    public static let cutBand: ClosedRange<Int> = 1_850...2_200
    /// Weeks 13–14 (plan §2): fixed, no trend steps.
    public static let maintenanceKcal = 2_450
    /// Overall weeks (from the programme start) that are a maintenance break.
    public static let maintenanceWeeks: ClosedRange<Int> = 13...14
    /// One step, never more than one a week.
    public static let stepKcal = 100
    /// The first week whose Monday check may move calories (weeks 1–2 are water weight).
    public static let firstCheckWeek = 3
    /// After a planned change this big, the next checks are skipped (water shifts).
    public static let bigChangeKcal = 200
    public static let checksSkippedAfterBigChange = 2
    /// A day planned by the meal planner (M3-02) sits within this of the week's
    /// target, and never under `dayFloorKcal`.
    public static let dayBandKcal = 150
    public static let dayFloorKcal = 1_700

    /// Claude may set calories inside these, and protein inside `importProteinG`.
    public static let importCutBand: ClosedRange<Int> = cutBand
    public static let importMaintenanceBand: ClosedRange<Int> = 2_300...2_600
    public static let importProteinG: ClosedRange<Int> = 140...180

    /// Stall flag: a 2-week rate below this (kg lost a week), two checks running.
    public static let stallRateKg = 0.2
    /// Muscle-loss risk: a 2-week rate above this, two checks running, at the ceiling.
    public static let tooFastRateKg = 1.2

    /// Target loss per week by phase, and the rates that move calories.
    public struct LossRate: Sendable, Equatable {
        /// The aim, kg lost per week.
        public let target: ClosedRange<Double>
        /// Losing less than this a week (or gaining): one step down.
        public let slowBelow: Double
        /// Losing more than this a week: one step up.
        public let fastAbove: Double
    }

    /// Phases 1–2: 0.4–0.8 kg a week; phase 3 is slower to keep muscle (Advisor).
    public static func lossRate(phase: Int) -> LossRate {
        phase >= 3
            ? LossRate(target: 0.3...0.6, slowBelow: 0.2, fastAbove: 0.8)
            : LossRate(target: 0.4...0.8, slowBelow: 0.3, fastAbove: 1.0)
    }

    public static func isMaintenance(week: Int) -> Bool { maintenanceWeeks.contains(week) }
}

/// What to eat this week, and why.
public struct CalorieTarget: Sendable, Equatable {
    public let kcal: Int
    public let proteinG: Int
    public let reason: Reason
    /// The most recent weekly check, if any has run.
    public let lastCheck: CalorieCheck?

    public enum Reason: String, Sendable, Equatable {
        /// Weeks 1–2, or no check has moved anything yet.
        case start
        /// Weeks 13–14: fixed, no trend steps.
        case maintenance
        /// The last check found the rate on track.
        case onTrack
        /// Losing slowly: one step down.
        case steppedDown
        /// Losing fast: one step up.
        case steppedUp
        /// Wanted to go lower, but this is the floor.
        case atFloor
        /// Wanted to go higher, but this is the ceiling.
        case atCeiling
        /// Too few weigh-ins to judge: unchanged.
        case notEnoughWeighIns
        /// Settling after a big change: unchanged.
        case settling
        /// Set by an imported Claude block.
        case imported
    }

    /// The band the meal planner (M3-02) plans each day inside.
    public var dayBand: ClosedRange<Int> {
        max(CalorieRules.dayFloorKcal, kcal - CalorieRules.dayBandKcal)...(kcal + CalorieRules.dayBandKcal)
    }

    /// "2,000 kcal and 160 g protein a day".
    public var summary: String {
        "\(CoachText.thousands(kcal)) kcal and \(proteinG) g protein a day"
    }
}

/// One Monday check: the 2-week rate and what it did.
public struct CalorieCheck: Sendable, Equatable {
    /// Monday of the overall week the check opens.
    public let date: Date
    public let week: Int
    /// kg lost per week over the last 2 weeks (negative = gained); nil without enough weigh-ins.
    public let lossRateKg: Double?
    public let kcalBefore: Int
    public let kcalAfter: Int
    public let outcome: CalorieTarget.Reason
}

extension CalorieRules {
    /// The overall week `date` falls in, counting 7-day weeks from `start`
    /// (the Monday of week 1). Not held at the programme's last week. Nil before the start.
    public static func week(of date: Date, start: Date, calendar: Calendar) -> Int? {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        return days >= 0 ? days / 7 + 1 : nil
    }

    /// The 2-week rate of loss, kg a week, from the 7-day averages ending on
    /// `day` and 14 days earlier (Advisor: one week swings ±0.3 kg on water).
    public static func lossRate(samples: [WeightSample], endingOn day: Date, calendar: Calendar) -> Double? {
        guard let earlier = calendar.date(byAdding: .day, value: -14, to: day),
              let now = WeightTrend.make(samples: samples, endingOn: day, calendar: calendar),
              let then = WeightTrend.make(samples: samples, endingOn: earlier, calendar: calendar)
        else { return nil }
        return (then.averageKg - now.averageKg) / 2
    }

    /// This week's target on `date`, replaying every Monday check since the
    /// start. `blocks` are the accepted Claude blocks; the latest one in force
    /// with `dailyKcal` resets calories, and the trend steps on from there.
    public static func target(on date: Date, start: Date, phase: Int, samples: [WeightSample],
                              blocks: [CoachBlock], calendar: Calendar) -> CalorieTarget {
        replay(to: date, start: start, phase: phase, samples: samples, blocks: blocks, calendar: calendar).target
    }

    /// The target plus every check that led to it, oldest first.
    static func replay(to date: Date, start: Date, phase: Int, samples: [WeightSample],
                       blocks: [CoachBlock], calendar: Calendar)
        -> (target: CalorieTarget, checks: [CalorieCheck]) {
        let protein = CoachBlock.inForce(blocks, on: date, calendar: calendar)
            .last(where: { $0.proteinG != nil })?.proteinG ?? proteinG
        guard let currentWeek = week(of: date, start: start, calendar: calendar) else {
            return (CalorieTarget(kcal: startKcal, proteinG: protein, reason: .start, lastCheck: nil), [])
        }
        let rate = lossRate(phase: phase)
        let startDay = calendar.startOfDay(for: start)
        func monday(_ week: Int) -> Date {
            calendar.date(byAdding: .day, value: (week - 1) * 7, to: startDay) ?? startDay
        }

        var kcal = startKcal            // the cut target, carried across maintenance
        var reason = CalorieTarget.Reason.start
        var maintenanceOverride: Int?   // an import in force during a maintenance break
        var skipChecks = 0
        var checks: [CalorieCheck] = []
        var lastKcalSeen = startKcal    // what the owner was actually eating
        let sortedBlocks = blocks
            .filter { $0.dailyKcal != nil && $0.effectiveFrom != nil }
            .sorted { $0.effectiveFrom! < $1.effectiveFrom! }
        var nextBlock = 0

        func applyBlocks(through end: Date) {
            while nextBlock < sortedBlocks.count, sortedBlocks[nextBlock].effectiveFrom! <= end {
                let block = sortedBlocks[nextBlock]
                nextBlock += 1
                guard let newKcal = block.dailyKcal,
                      let blockWeek = week(of: block.effectiveFrom!, start: start, calendar: calendar) else { continue }
                if isMaintenance(week: blockWeek) {
                    maintenanceOverride = newKcal
                } else {
                    kcal = newKcal
                    reason = .imported
                }
                // Any import lets one check pass before the trend moves things again;
                // a big one, two (water shifts).
                skipChecks = max(skipChecks, abs(newKcal - lastKcalSeen) >= bigChangeKcal ? checksSkippedAfterBigChange : 1)
                lastKcalSeen = newKcal
            }
        }

        for week in 1...currentWeek {
            let weekStart = monday(week)
            // Blocks effective before this Monday apply first; a block on the Monday itself wins over the check.
            applyBlocks(through: calendar.date(byAdding: .second, value: -1, to: weekStart) ?? weekStart)

            if isMaintenance(week: week) {
                if !isMaintenance(week: week - 1) {
                    maintenanceOverride = nil
                    if abs(maintenanceKcal - kcal) >= bigChangeKcal { skipChecks = checksSkippedAfterBigChange }
                }
                lastKcalSeen = maintenanceKcal
            } else {
                if week > 1, isMaintenance(week: week - 1) {
                    // Out of maintenance: back to the cut target, and let the water settle.
                    if abs(lastKcalSeen - kcal) >= bigChangeKcal { skipChecks = checksSkippedAfterBigChange }
                    lastKcalSeen = kcal
                }
                if week >= firstCheckWeek {
                    let sunday = calendar.date(byAdding: .day, value: -1, to: weekStart) ?? weekStart
                    let measured = lossRate(samples: samples, endingOn: sunday, calendar: calendar)
                    let before = kcal
                    var outcome: CalorieTarget.Reason
                    if skipChecks > 0 {
                        skipChecks -= 1
                        outcome = .settling
                    } else if let loss = measured {
                        if loss < rate.slowBelow {
                            if kcal <= cutBand.lowerBound {
                                kcal = cutBand.lowerBound
                                outcome = .atFloor
                            } else {
                                kcal = max(cutBand.lowerBound, kcal - stepKcal)
                                outcome = .steppedDown
                            }
                        } else if loss > rate.fastAbove {
                            if kcal >= cutBand.upperBound {
                                kcal = cutBand.upperBound
                                outcome = .atCeiling
                            } else {
                                kcal = min(cutBand.upperBound, kcal + stepKcal)
                                outcome = .steppedUp
                            }
                        } else {
                            outcome = .onTrack
                        }
                    } else {
                        outcome = .notEnoughWeighIns
                    }
                    reason = outcome
                    lastKcalSeen = kcal
                    checks.append(CalorieCheck(date: weekStart, week: week, lossRateKg: measured,
                                               kcalBefore: before, kcalAfter: kcal, outcome: outcome))
                }
            }
        }
        applyBlocks(through: date)

        let last = checks.last
        if isMaintenance(week: currentWeek) {
            return (CalorieTarget(kcal: maintenanceOverride ?? maintenanceKcal, proteinG: protein,
                                  reason: maintenanceOverride == nil ? .maintenance : .imported, lastCheck: last), checks)
        }
        return (CalorieTarget(kcal: kcal, proteinG: protein, reason: reason, lastCheck: last), checks)
    }
}
