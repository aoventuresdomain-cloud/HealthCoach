import Foundation

/// C6: the player's "last time → today" line for a lift, so progression is
/// visible where it happens. Built from the most recent log of that exercise
/// (any session), against today's prescription.
public enum LastTime {
    /// "Last time 8 @ 10 kg → today 9 @ 10 kg", "Last time 20 s → today 25 s".
    /// Nil when the exercise has never been logged.
    public static func line(_ step: WorkoutScript.SetStep, history: [SessionLog]) -> String? {
        guard let latest = history
            .filter({ log in log.sets.contains { $0.exercise == step.exercise } })
            .max(by: { $0.startedAt < $1.startedAt }) else { return nil }
        let sets = latest.sets.filter { $0.exercise == step.exercise }
        // The best set: heaviest, then most reps or seconds at that load.
        let kg = sets.compactMap(\.kg).max()
        let atLoad = sets.filter { $0.kg == kg }
        let amount = atLoad.compactMap { $0.reps ?? $0.seconds }.max() ?? 0
        let before = text(amount: amount, timed: atLoad.first?.seconds != nil, perSide: isPerSide(step), kg: kg)
        let today = text(amount: target(step), timed: isTimed(step), perSide: isPerSide(step), kg: step.kg)
        return "Last time \(before) → today \(today)"
    }

    /// One line per exercise of the script, keyed by exercise id.
    public static func lines(for script: WorkoutScript, history: [SessionLog]) -> [String: String] {
        var out: [String: String] = [:]
        for step in script.sets where out[step.exercise] == nil {
            if let line = line(step, history: history) { out[step.exercise] = line }
        }
        return out
    }

    static func text(amount: Int, timed: Bool, perSide: Bool, kg: Double?) -> String {
        let what = timed ? "\(amount) s" : (perSide ? "\(amount) each side" : "\(amount)")
        return what + (kg.map { " @ \(PlayerCues.kilos($0)) kg" } ?? "")
    }

    static func target(_ step: WorkoutScript.SetStep) -> Int {
        switch step.kind {
        case let .reps(reps), let .perSide(reps), let .negatives(reps, _): reps
        case let .hold(seconds): seconds
        }
    }

    static func isTimed(_ step: WorkoutScript.SetStep) -> Bool {
        if case .hold = step.kind { return true }
        return false
    }

    static func isPerSide(_ step: WorkoutScript.SetStep) -> Bool {
        if case .perSide = step.kind { return true }
        return false
    }
}
