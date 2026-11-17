import Foundation

/// Strength by lift for the Progress view (plan §4.6): one point per logged
/// session, the heaviest set that day (most reps at that weight breaking ties).
public enum StrengthProgress {
    public struct Point: Sendable, Equatable {
        public let date: Date
        /// Per dumbbell; nil for bodyweight and timed moves.
        public let kg: Double?
        public let reps: Int?
        public let seconds: Int?
    }

    public struct Lift: Sendable, Equatable {
        public let exercise: String
        public let points: [Point]

        public var first: Point? { points.first }
        public var latest: Point? { points.last }
    }

    /// Every exercise with at least one logged set, most-logged first, then by name.
    /// Points are oldest first.
    public static func lifts(from history: [SessionLog]) -> [Lift] {
        var byExercise: [String: [Point]] = [:]
        for log in history.sorted(by: { $0.startedAt < $1.startedAt }) {
            var best: [String: SetLog] = [:]
            for set in log.sets {
                if let current = best[set.exercise], !isBetter(set, than: current) { continue }
                best[set.exercise] = set
            }
            for (exercise, set) in best {
                byExercise[exercise, default: []].append(
                    Point(date: log.startedAt, kg: set.kg, reps: set.reps, seconds: set.seconds))
            }
        }
        return byExercise
            .map { Lift(exercise: $0.key, points: $0.value) }
            .sorted { $0.points.count != $1.points.count ? $0.points.count > $1.points.count : $0.exercise < $1.exercise }
    }

    /// "10 kg × 8 → 12 kg × 9", or "20 s → 35 s"; one value when only one session.
    public static func change(_ lift: Lift) -> String {
        guard let first = lift.first, let latest = lift.latest else { return "" }
        let a = describe(first), b = describe(latest)
        return lift.points.count < 2 || a == b ? b : "\(a) → \(b)"
    }

    /// True only when the latest best set is heavier than the first. Held or
    /// lighter loads are not flagged at all: they show neutral, never red (UI pass).
    public static func loadWentUp(_ lift: Lift) -> Bool {
        guard let first = lift.first?.kg, let latest = lift.latest?.kg else { return false }
        return latest > first
    }

    static func describe(_ point: Point) -> String {
        if let seconds = point.seconds { return "\(seconds) s" }
        let reps = point.reps.map { "\($0)" } ?? "?"
        guard let kg = point.kg else { return "\(reps) reps" }
        return "\(PlayerCues.kilos(kg)) kg × \(reps)"
    }

    private static func isBetter(_ a: SetLog, than b: SetLog) -> Bool {
        let ak = a.kg ?? 0, bk = b.kg ?? 0
        if ak != bk { return ak > bk }
        let aa = a.reps ?? a.seconds ?? 0, ba = b.reps ?? b.seconds ?? 0
        return aa > ba
    }
}
