import Foundation

// Board M4-01: the rules engine's weekly answer. Calories come from the trend
// (CalorieRules), load from the logs (Progression, plus any imported loads),
// volume from recovery (R2 reduced week, plus any imported drops). The stall
// flag asks the owner to share a summary with Claude; a flag never changes
// the plan by itself.

/// Why the coach suggests asking Claude now.
public enum CoachFlag: Sendable, Equatable {
    /// Weight hasn't moved for two checks running, or calories are at the floor
    /// and still too high. Ask Claude.
    case stall(StallReason)
    /// End of a phase (weeks 6, 14 and 20): the planned Claude review.
    case checkpoint(Int)

    public enum StallReason: String, Sendable, Equatable {
        /// 2-week rate under 0.2 kg a week (or a gain), two checks running.
        case weightFlat
        /// The last check wanted fewer calories than the floor allows.
        case calorieFloor
        /// Losing over 1.2 kg a week (1.0 in phase 3) for two checks while at the ceiling: muscle-loss risk.
        case losingTooFast
    }

    /// The one line on Today.
    public var line: String {
        switch self {
        case .stall(.weightFlat): "Your weight has been flat for 2 weeks. Ask the coach."
        case .stall(.calorieFloor): "Calories are as low as they go and weight is flat. Ask the coach."
        case .stall(.losingTooFast): "You're losing weight too fast to keep muscle. Ask the coach."
        case let .checkpoint(n): "Checkpoint \(n): time for your coach review."
        }
    }
}

/// Everything the rules engine decides for one day of the plan.
public struct CoachReview: Sendable, Equatable {
    /// Overall week from the programme start (not held at the programme's last week).
    public let week: Int
    public let calories: CalorieTarget
    /// Sessions to leave out (R2 reduced week plus imported drops). Pass to
    /// `WeekPlanner.plan(dropping:)` and `DayPlan.make(dropping:)`.
    public let droppedSessions: Set<String>
    /// Exercises whose next load step would pass the heaviest dumbbell (D3).
    public let dumbbellLimit: [String]
    public let flags: [CoachFlag]
    /// The latest imported block in force, for Today's note.
    public let block: CoachBlock?

    /// Overall weeks whose end is a Claude checkpoint (plan §2).
    public static let checkpointWeeks = [6, 14, 20]

    /// The review for `now`. Nil before onboarding sets a start date.
    public static func make(programme: Programme, profile: Profile, history: [SessionLog],
                            weights: [WeightSample], blocks: [CoachBlock], checkIns: [CheckIn] = [],
                            now: Date, calendar: Calendar = .current) -> CoachReview? {
        guard let start = profile.programme.startDate,
              let week = CalorieRules.week(of: now, start: start, calendar: calendar) else { return nil }
        let replay = CalorieRules.replay(to: now, start: start, phase: programme.phase, samples: weights,
                                         blocks: blocks, calendar: calendar)
        // N1: a check-in with low energy and poor sleep is a low-recovery signal too.
        let dropped = Set(programme.droppedSessions(history: history, checkIns: checkIns))
            .union(CoachBlock.droppedSessions(blocks, on: now, start: start, calendar: calendar))

        let programmeWeek = programme.plannedDay(on: now, start: start, calendar: calendar).week
        var limit: [String] = []
        if let programmeWeek {
            for item in programme.strengthItems {
                guard let rx = programme.prescription(for: item, week: programmeWeek, history: history,
                                                      blocks: blocks, checkIns: checkIns, on: now, calendar: calendar),
                      rx.atDumbbellLimit, !limit.contains(rx.exercise) else { continue }
                limit.append(rx.exercise)
            }
        }

        var flags: [CoachFlag] = []
        if let stall = stallReason(checks: replay.checks, blocks: blocks, now: now, week: week, phase: programme.phase) {
            flags.append(.stall(stall))
        }
        if let checkpoint = checkpointDue(now: now, start: start, blocks: blocks, calendar: calendar) {
            flags.append(.checkpoint(checkpoint))
        }

        return CoachReview(week: week, calories: replay.target, droppedSessions: dropped,
                           dumbbellLimit: limit.sorted(), flags: flags,
                           block: CoachBlock.latest(blocks, on: now, calendar: calendar))
    }

    /// The stall flag, from the last two weekly checks. None in maintenance
    /// weeks, and none once a block has been imported since the second check
    /// (the owner has already asked).
    static func stallReason(checks: [CalorieCheck], blocks: [CoachBlock], now: Date,
                            week: Int, phase: Int) -> CoachFlag.StallReason? {
        guard !CalorieRules.isMaintenance(week: week), let last = checks.last else { return nil }
        if blocks.contains(where: { ($0.importedAt ?? .distantPast) >= last.date }) { return nil }
        if last.outcome == .atFloor { return .calorieFloor }
        guard checks.count >= 2 else { return nil }
        let pair = checks.suffix(2)
        // Two checks running means consecutive weeks, both measured.
        guard pair.last!.week == pair.first!.week + 1 else { return nil }
        let rates = pair.compactMap(\.lossRateKg)
        guard rates.count == 2 else { return nil }
        if rates.allSatisfy({ $0 < CalorieRules.stallRateKg }) { return .weightFlat }
        if rates.allSatisfy({ $0 > CalorieRules.tooFastRateKg(phase: phase) }),
           pair.allSatisfy({ $0.kcalAfter >= CalorieRules.cutBand.upperBound }) {
            return .losingTooFast
        }
        return nil
    }

    /// The checkpoint number if one is due: from the Saturday of week 6, 14 or
    /// 20 to the end of the following week, until a block is imported.
    static func checkpointDue(now: Date, start: Date, blocks: [CoachBlock], calendar: Calendar) -> Int? {
        let startDay = calendar.startOfDay(for: start)
        for (index, week) in checkpointWeeks.enumerated() {
            guard let opens = calendar.date(byAdding: .day, value: (week - 1) * 7 + 5, to: startDay),
                  let closes = calendar.date(byAdding: .day, value: week * 7 + 7, to: startDay) else { continue }
            guard now >= opens, now < closes else { continue }
            if blocks.contains(where: { ($0.importedAt ?? .distantPast) >= opens }) { return nil }
            return index + 1
        }
        return nil
    }
}

extension CoachReview {
    /// C2: Today's one coach line, or nil when nothing needs the coach. A stall
    /// or checkpoint flag comes first; otherwise the dumbbell limit. `name`
    /// turns an exercise id into its display name.
    public func todayLine(name: (String) -> String) -> String? {
        if let flag = flags.first { return flag.line }
        guard let first = dumbbellLimit.first else { return nil }
        let others = dumbbellLimit.count - 1
        let who = others == 0 ? "\(name(first)) is" : "\(name(first)) and \(others) more are"
        return "\(who) at your heaviest dumbbell. Ask the coach."
    }
}

extension Programme {
    /// Every strength item across sessions, once per exercise.
    var strengthItems: [StrengthItem] {
        var seen = Set<String>()
        var items: [StrengthItem] = []
        for id in sessions.keys.sorted() {
            guard case let .strength(s) = sessions[id] else { continue }
            for item in s.blocks.flatMap(\.items) where seen.insert(item.exercise).inserted {
                items.append(item)
            }
        }
        return items
    }

    /// The prescription with any imported load applied (board M4-02). An
    /// imported weight holds until the owner next logs that exercise; from
    /// then on the logged weight is the starting point, as usual.
    public func prescription(for item: StrengthItem, week: Int, history: [SessionLog],
                             blocks: [CoachBlock], checkIns: [CheckIn] = [], on date: Date,
                             calendar: Calendar = .current) -> Prescription? {
        // N8: after 10+ days without strength work, loads ease and rebuild;
        // N1: a pain answer holds the step.
        guard let base = easedPrescription(for: item, week: week, history: history, checkIns: checkIns,
                                           on: date, calendar: calendar)
        else { return nil }
        let lastLogged = history
            .filter { log in log.sets.contains { $0.exercise == base.exercise } }
            .map(\.startedAt).max() ?? .distantPast
        guard let imported = CoachBlock.inForce(blocks, on: date, calendar: calendar)
            .filter({ ($0.effectiveFrom ?? .distantPast) > lastLogged })
            .compactMap({ $0.loads.first { $0.exercise == base.exercise } })
            .last,
            base.kg != nil else { return base }
        let kg = min(imported.kg, dumbbellLimitKg)
        return Prescription(
            exercise: base.exercise, sets: base.sets, repsInReserve: base.repsInReserve,
            reps: base.reps.map { _ in base.range.min }, seconds: base.seconds.map { _ in base.range.min },
            range: base.range, kg: kg, slowTempo: false,
            atDumbbellLimit: item.progression.addsLoad && kg + loadStepKg > dumbbellLimitKg,
            step: .coach)
    }
}
