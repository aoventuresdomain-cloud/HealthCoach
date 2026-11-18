import Foundation

// Board N2: "What changed and why". The engine moves calories on the trend,
// steps loads on the logs, flags the dumbbell limit and applies Claude's
// blocks, and until now no screen said so. This compares what the plan asks
// for now with what it asked for a week ago and gives one plain line per
// change, with its reason. Stateless like the rest of the coach: it replays
// both moments from the logs, weigh-ins and blocks. Progress and the Sunday
// check-in (N1) show the lines; no lines, no card.

/// One change to the plan, and why.
public struct CoachChange: Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case coachReply, calories, protein, sessions
        /// N1: knee or back pain turns the run-walk into a brisk walk.
        case runWalk
        /// N1: an exercise swapped for one that spares a sore area.
        case painSwap
        case load, dumbbellLimit
    }

    public let kind: Kind
    /// "Calories 2,000 → 1,900: weight flat for 2 weeks".
    public let line: String
}

public enum CoachChanges {
    /// How far back "changed" looks: the week since the last check-in.
    public static let windowDays = 7

    /// The changes between `now − windowDays` and `now`, in reading order:
    /// Claude's reply, calories, protein, sessions, the run-walk and pain
    /// swaps (N1), loads, dumbbell limits. `name` turns an exercise id into its
    /// display name. `checkIns` may include one still being answered, dated
    /// `now`: its pain counts for the 7 days from then. Pain swap lines need
    /// `exercises`. Empty when nothing changed, or before onboarding.
    public static func make(programme: Programme, profile: Profile, history: [SessionLog],
                            weights: [WeightSample], blocks: [CoachBlock], checkIns: [CheckIn] = [],
                            exercises: ExerciseCatalogue? = nil, now: Date,
                            name: (String) -> String = { $0 }, calendar: Calendar = .current) -> [CoachChange] {
        guard let start = profile.programme.startDate, now >= start else { return [] }
        // N1: pain from the check-ins in force now (Advisor conditions: one
        // run-walk line; "Other" never shows; a dropped exercise gets no line).
        // Needs no week to compare with, so the first Sunday's check-in shows it too.
        let pain = painChanges(programme: programme, start: start, checkIns: checkIns, exercises: exercises,
                               now: now, name: name, calendar: calendar)
        guard let then = calendar.date(byAdding: .day, value: -windowDays, to: now), then >= start else { return pain }
        // What the app knew a week ago: only logs, weigh-ins and imports from before then.
        let oldHistory = history.filter { $0.startedAt < then }
        let oldWeights = weights.filter { $0.date < then }
        let oldBlocks = blocks.filter { ($0.importedAt ?? .distantPast) < then }
        guard let before = CoachReview.make(programme: programme, profile: profile, history: oldHistory,
                                            weights: oldWeights, blocks: oldBlocks, now: then, calendar: calendar),
              let after = CoachReview.make(programme: programme, profile: profile, history: history,
                                           weights: weights, blocks: blocks, now: now, calendar: calendar)
        else { return pain }

        var changes: [CoachChange] = []
        let replies = blocks.filter { block in
            guard let at = block.importedAt else { return false }
            return at >= then && at <= now
        }
        for block in replies.sorted(by: { ($0.importedAt ?? now) < ($1.importedAt ?? now) }) {
            let day = CoachText.day(block.importedAt ?? now, calendar: calendar)
            let note = block.note.map { ": \($0)" } ?? ""
            let starts = (block.effectiveFrom ?? now) > now ? ", applies from tomorrow" : ""
            changes.append(CoachChange(kind: .coachReply, line: "Claude's reply imported \(day)\(starts)\(note)"))
        }

        // Calories and protein.
        let fromReply = after.calories.reason == .imported
        if after.calories.kcal != before.calories.kcal {
            let reason = fromReply ? "set by Claude's reply"
                : caloriesReason(after.calories, wasMaintenance: before.calories.reason == .maintenance,
                                 phase: programme.phase)
            changes.append(CoachChange(kind: .calories, line: "Calories \(CoachText.thousands(before.calories.kcal)) → \(CoachText.thousands(after.calories.kcal)): \(reason)"))
        }
        if after.calories.proteinG != before.calories.proteinG {
            changes.append(CoachChange(kind: .protein, line: "Protein \(before.calories.proteinG) → \(after.calories.proteinG) g: set by Claude's reply"))
        }

        // Sessions left out, or back in.
        let byReply = CoachBlock.droppedSessions(blocks, on: now, start: start, calendar: calendar)
        for id in after.droppedSessions.subtracting(before.droppedSessions).sorted() {
            let reason = byReply.contains(id) ? "Claude's reply" : "sore after the last 2 strength sessions, so an easier week"
            changes.append(CoachChange(kind: .sessions, line: "\(sessionName(id, programme)) left out: \(reason)"))
        }
        for id in before.droppedSessions.subtracting(after.droppedSessions).sorted() {
            changes.append(CoachChange(kind: .sessions, line: "\(sessionName(id, programme)) back in the plan"))
        }

        changes += pain

        // Loads: the weight each lift asks for next, then and now.
        let weekThen = programme.plannedDay(on: then, start: start, calendar: calendar).week
        let weekNow = programme.plannedDay(on: now, start: start, calendar: calendar).week
        if let weekThen, let weekNow {
            for item in programme.strengthItems where item.startKg != nil {
                guard let old = programme.prescription(for: item, week: weekThen, history: oldHistory,
                                                       blocks: oldBlocks, on: then, calendar: calendar),
                      let new = programme.prescription(for: item, week: weekNow, history: history,
                                                       blocks: blocks, on: now, calendar: calendar),
                      let oldKg = old.kg, let newKg = new.kg, oldKg != newKg, old.exercise == new.exercise
                else { continue }
                let reason = switch new.step {
                case .coach: "set by Claude's reply"
                case .easing: "easing back in after a break"
                case .addLoad: newKg > oldKg ? "top of the range done last time, so one step up" : "back to the bottom of the range"
                default: newKg > oldKg ? "progressing on your logs" : "eased back on your logs"
                }
                changes.append(CoachChange(kind: .load, line: "\(name(new.exercise)) \(CoachText.kg(oldKg)) → \(CoachText.kg(newKg)) per dumbbell: \(reason)"))
            }
        }

        // The dumbbells newly the limit (decision D3).
        for exercise in after.dumbbellLimit where !before.dumbbellLimit.contains(exercise) {
            changes.append(CoachChange(kind: .dumbbellLimit, line: "\(name(exercise)) is at the \(CoachText.kg(programme.dumbbellLimitKg)) dumbbells: progress now comes from reps and a slower tempo. Worth asking the coach about heavier dumbbells."))
        }
        return changes
    }

    static func painChanges(programme: Programme, start: Date, checkIns: [CheckIn], exercises: ExerciseCatalogue?,
                            now: Date, name: (String) -> String, calendar: Calendar) -> [CoachChange] {
        let areas = CheckIn.painAreas(checkIns, on: now, calendar: calendar)
        guard !areas.isEmpty else { return [] }
        var out: [CoachChange] = []

        if let week = programme.plannedDay(on: now, start: start, calendar: calendar).week {
            let walk = programme.sessions.sorted { $0.key < $1.key }.lazy.compactMap { id, session -> Int? in
                guard case let .runWalk(run) = session,
                      let plan = RunWalkPlan.briskWalk(sessionID: id, session: run, week: week) else { return nil }
                return plan.segments.reduce(0) { $0 + $1.seconds } / 60
            }.first
            if let minutes = walk, let line = PainSwaps.runWalkLine(areas: areas, minutes: minutes) {
                out.append(CoachChange(kind: .runWalk, line: line))
            }
        }

        guard let exercises else { return out }
        var ids: [String] = []
        for id in PainSwaps.exercises(in: programme) where !ids.contains(id) { ids.append(id) }
        let swaps = PainSwaps.make(areas: areas, exercises: ids, catalogue: exercises)
        for id in ids {
            guard let to = swaps[id]?.to else { continue }   // not swapped, or dropped: no line
            let spared = PainArea.allCases.filter { $0 != .other && areas.contains($0)
                && (exercises.exercise(id)?.loads ?? []).contains($0) }
            let why = spared.isEmpty ? "" : ": easier on the " + spared.map(\.rawValue).joined(separator: " and ")
            out.append(CoachChange(kind: .painSwap, line: "\(name(id)) → \(name(to)) this week\(why)"))
        }
        return out
    }

    static func caloriesReason(_ target: CalorieTarget, wasMaintenance: Bool, phase: Int) -> String {
        let rate = target.lastCheck?.lossRateKg
        let aim = CalorieRules.lossRate(phase: phase).target
        let aimText = "aim \(CoachText.number(aim.lowerBound))–\(CoachText.number(aim.upperBound)) kg"
        switch target.reason {
        case .maintenance:
            return "maintenance break, weeks 13–14"
        case .steppedDown:
            guard let rate else { return "losing slowly" }
            if rate < CalorieRules.stallRateKg { return "weight flat for 2 weeks" }
            return "losing \(CoachText.kg(rate)) a week over 2 weeks (\(aimText))"
        case .steppedUp:
            guard let rate else { return "losing fast" }
            return "losing \(CoachText.kg(rate)) a week over 2 weeks, faster than the \(aimText), so more to keep muscle"
        default:
            return wasMaintenance ? "maintenance break over, back to the cut" : CoachSummary.reasonText(target.reason)
        }
    }

    static func sessionName(_ id: String, _ programme: Programme) -> String {
        programme.sessions[id]?.name ?? id
    }
}
