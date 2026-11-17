import Foundation

/// The done screen's "Next time" lines (QA-13): what the next run of this
/// session asks for, after the one just logged. The visible proof that
/// progression is automatic.
public enum NextTime {
    public struct Line: Sendable, Equatable {
        public let exercise: String
        /// "2 × 9 @ 10 kg", "3 × 25 s", "2 × 10 each side @ 6 kg", " · slow lower" when the tempo step applies.
        public let text: String
        /// The next load is heavier than today's heaviest set (shown green with
        /// an up arrow). Held or lighter stays neutral: never red (UI-9).
        public let loadUp: Bool

        public init(exercise: String, text: String, loadUp: Bool = false) {
            self.exercise = exercise
            self.text = text
            self.loadUp = loadUp
        }
    }

    /// One line per exercise, in session order, for the session's next week
    /// (the same week when this was the programme's last). `history` must
    /// already include the session just finished.
    public static func lines(sessionID: String, programme: Programme, week: Int,
                             history: [SessionLog]) -> [Line] {
        let next = min(week + 1, programme.weeks)
        guard let script = WorkoutScript.make(sessionID: sessionID, programme: programme, week: next, history: history)
                ?? WorkoutScript.make(sessionID: sessionID, programme: programme, week: week, history: history)
        else { return [] }
        var seen = Set<String>()
        let latest = history.filter { $0.sessionID == sessionID }.max { $0.startedAt < $1.startedAt }
        return script.sets.compactMap { step in
            guard seen.insert(step.exercise).inserted else { return nil }
            let today = latest?.sets.filter { $0.exercise == step.exercise }.compactMap(\.kg).max()
            let up = step.kg.map { next in today.map { next > $0 } ?? false } ?? false
            return Line(exercise: step.exercise, text: text(step), loadUp: up)
        }
    }

    static func text(_ step: WorkoutScript.SetStep) -> String {
        let amount: String
        switch step.kind {
        case let .reps(target): amount = "\(target)"
        case let .perSide(target): amount = "\(target) each side"
        case let .hold(seconds): amount = "\(seconds) s"
        case let .negatives(reps, lower): amount = "\(reps) lowers, \(lower) s"
        }
        let load = step.kg.map { " @ \(PlayerCues.kilos($0)) kg" } ?? ""
        let tempo = step.slowTempo ? " · slow lower" : ""
        return "\(step.setCount) × \(amount)\(load)\(tempo)"
    }
}
