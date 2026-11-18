import Foundation

/// What the player shows for one strength item next session (board M1-08).
///
/// The plan's order is "reps, then sets, then tempo, then weight". Sets come
/// from the programme's weekly ramp (`StrengthItem.sets`), so this engine only
/// moves reps (or seconds), tempo and weight, by the item's `progression` rule.
public struct Prescription: Sendable, Equatable {
    /// The exercise to do: the item's own, or its `graduate.to` once earned.
    public let exercise: String
    public let sets: Int
    public let repsInReserve: Int
    /// Target reps per set; nil for a timed item.
    public let reps: Int?
    /// Target seconds per set; nil for a reps item.
    public let seconds: Int?
    /// The range the target climbs through.
    public let range: IntRange
    /// Per dumbbell; nil = bodyweight.
    public let kg: Double?
    /// Lower over 3 seconds (the tempo step).
    public let slowTempo: Bool
    /// The next load step would go past the heaviest dumbbell (decision D3):
    /// the owner should know the dumbbells are now the limit.
    public let atDumbbellLimit: Bool
    /// Why this is the prescription, for the player's one-line note.
    public let step: Step

    public enum Step: String, Sendable, Equatable {
        /// Never logged: the programme's starting point.
        case start
        /// Every set hit the target: one more rep (or 5 more seconds).
        case climb
        /// Top of the range at normal tempo: same reps, lowered over 3 s.
        case slowTempo
        /// Top of the range done: one load step, back to the bottom.
        case addLoad
        /// Top of the range and no further step in this rule: stay here.
        case top
        /// A set fell short (not two in a row): same as last time. Never a failure.
        case held
        /// Two sets in a row fell short: back to the bottom of the range.
        case backOff
        /// Moved to the harder exercise (`graduate.to`), at the bottom of its range.
        case graduated
        /// Set by an imported Claude block (M4-02), at the bottom of the range.
        case coach
        /// Eased after a break from strength work (N8, Advisor A2).
        case easing
    }
}

extension Programme {
    /// Seconds added per session by the `time` rules.
    public static let timeStepSeconds = 5

    /// The prescription for `item` in `week`, from every logged session so far.
    /// Returns nil when the item has no sets that week.
    ///
    /// History is matched by exercise, across sessions: a lateral raise in
    /// Upper A moves the lateral raise in Upper B too. Sessions are replayed in
    /// order, so no target needs storing; a logged weight replaces the
    /// prescribed one (the owner picked a different dumbbell).
    public func prescription(for item: StrengthItem, week: Int, history: [SessionLog]) -> Prescription? {
        guard week >= 1, week <= item.sets.count, item.sets[week - 1] > 0 else { return nil }
        var state = Track.start(item)
        for log in history.sorted(by: { $0.startedAt < $1.startedAt }) {
            let sets = log.sets
                .filter { $0.exercise == state.exercise }
                .sorted { $0.setIndex < $1.setIndex }
            guard !sets.isEmpty else { continue }
            state = advance(state, after: sets, item: item)
        }
        return Prescription(
            exercise: state.exercise,
            sets: item.sets[week - 1],
            repsInReserve: item.repsInReserve[min(week, item.repsInReserve.count) - 1],
            reps: state.rule.isTimed ? nil : state.target,
            seconds: state.rule.isTimed ? state.target : nil,
            range: state.range,
            kg: state.kg,
            slowTempo: state.slowTempo,
            atDumbbellLimit: state.rule.addsLoad && state.kg.map { $0 + loadStepKg > dumbbellLimitKg } == true,
            step: state.step)
    }

    /// The exercise the player switches to mid-session when the first set falls
    /// short (`autoSwap`), moved by the double-progression rule on its own history.
    public func swapPrescription(for item: StrengthItem, week: Int, history: [SessionLog]) -> Prescription? {
        guard let swap = item.autoSwap else { return nil }
        let swapped = StrengthItem(
            exercise: swap.to, sets: item.sets, repsInReserve: item.repsInReserve,
            reps: swap.reps, seconds: nil, perSide: false, startKg: swap.startKg,
            tempo: item.tempo, progression: swap.startKg == nil ? .reps : .double,
            note: swap.note, graduate: nil, autoSwap: nil)
        return prescription(for: swapped, week: week, history: history)
    }

    /// True when the last two answers to "Still sore from last time?" were
    /// "Sore": the coming week drops `reducedWeek.drop` (decision R2). An
    /// unanswered check counts as fine, so ignoring the row never drops a session.
    public func reducedWeekApplies(history: [SessionLog]) -> Bool {
        var strengthIDs = Set<String>()
        for (id, session) in sessions {
            if case .strength = session { strengthIDs.insert(id) }
        }
        let recent = history
            .filter { strengthIDs.contains($0.sessionID) }
            .sorted { $0.startedAt < $1.startedAt }
            .suffix(2)
        return recent.count == 2 && recent.allSatisfy { $0.recovery == .sore }
    }

    /// The session ids to leave out of the coming week (empty for a normal week).
    public func droppedSessions(history: [SessionLog]) -> [String] {
        reducedWeekApplies(history: history) ? reducedWeek.drop : []
    }

    // MARK: - Replay

    private struct Track {
        var exercise: String
        var rule: Progression
        var range: IntRange
        var target: Int
        var kg: Double?
        var slowTempo = false
        var step: Prescription.Step = .start

        static func start(_ item: StrengthItem) -> Track {
            let range = item.reps ?? item.seconds ?? IntRange(min: 0, max: 0)
            return Track(exercise: item.exercise, rule: item.progression,
                         range: range, target: range.min, kg: item.startKg)
        }
    }

    private enum Outcome { case met, held, short }

    private func advance(_ previous: Track, after sets: [SetLog], item: StrengthItem) -> Track {
        var state = previous
        if let logged = sets.compactMap(\.kg).first { state.kg = logged }
        if sets.contains(where: \.slowTempo) { state.slowTempo = true }

        let rule = state.rule
        func count(_ set: SetLog) -> Int? { rule.isTimed ? set.seconds : set.reps }
        // A set with no count that wasn't tapped "as prescribed" (counter unused,
        // phone dropped) says nothing either way, so it never holds progression back.
        let sets = sets.filter { $0.asPrescribed || count($0) != nil }
        guard !sets.isEmpty else {
            state.step = .held
            return state
        }
        let target = state.target
        let met: [Bool] = sets.map { set in
            set.asPrescribed || (count(set) ?? 0) >= target
        }
        let outcome: Outcome
        if met.allSatisfy({ $0 }) {
            outcome = .met
        } else if zip(met, met.dropFirst()).contains(where: { pair in !pair.0 && !pair.1 }) {
            outcome = .short
        } else {
            outcome = .held
        }

        switch outcome {
        case .held:
            state.step = .held
            return state
        case .short:
            state.step = .backOff
            if state.target > state.range.min || state.slowTempo {
                state.target = state.range.min
                state.slowTempo = false
            } else if let kg = state.kg, kg - loadStepKg >= loadStepKg {
                state.kg = kg - loadStepKg
            }
            return state
        case .met:
            break
        }

        // Every set hit the target. Logged counts can jump the target forward.
        let lowest = sets.map { set in
            set.asPrescribed ? max(count(set) ?? target, target) : (count(set) ?? target)
        }.min() ?? target
        let atTop = lowest >= state.range.max

        if !atTop {
            let step = state.rule.isTimed ? Self.timeStepSeconds : 1
            state.target = min(state.range.max, max(state.target + step, lowest))
            state.step = .climb
            return state
        }

        state.target = state.range.max
        switch state.rule {
        case .double, .timeThenLoad:
            return addLoad(state)
        case .repsTempoLoad:
            if state.slowTempo { return addLoad(state) }
            state.slowTempo = true
            state.step = .slowTempo
            return state
        case .repsTempo:
            if state.slowTempo {
                state.step = .top
            } else {
                state.slowTempo = true
                state.step = .slowTempo
            }
            return state
        case .reps, .time:
            state.step = .top
            return state
        case .repsThenGraduate:
            guard let graduate = item.graduate, state.exercise == item.exercise,
                  sets.count >= (item.sets.max() ?? 0) else {
                state.step = .top
                return state
            }
            return Track(exercise: graduate.to, rule: .reps, range: graduate.reps,
                         target: graduate.reps.min, kg: nil, step: .graduated)
        }
    }

    private func addLoad(_ previous: Track) -> Track {
        var state = previous
        guard let kg = state.kg else {
            state.step = .top
            return state
        }
        let next = kg + loadStepKg
        if next > dumbbellLimitKg {
            state.step = .top
            return state
        }
        state.kg = next
        state.target = state.range.min
        state.slowTempo = false
        state.step = .addLoad
        return state
    }
}
