import Foundation

/// One week's run-walk as a list of timed segments (board M1-07): warm-up
/// walk → jog/walk intervals → cool-down walk, with what the voice says at
/// each change. All lengths come from the programme data.
public struct RunWalkPlan: Equatable, Sendable {
    public let sessionID: String
    public let name: String
    public let week: Int
    public let segments: [Segment]

    public struct Segment: Equatable, Sendable {
        public enum Kind: String, Sendable { case warmUp, jog, walk, coolDown }
        public let kind: Kind
        public let seconds: Int
        /// 1-based jog number for intervals; nil for warm-up and cool-down.
        public let interval: Int?

        public var isJog: Bool { kind == .jog }
    }

    /// The effort, set once by the first cue and repeated on screen (design M1-03).
    public static let effortLine = "Easy pace: you could chat."

    public var totalSeconds: Int { segments.map(\.seconds).reduce(0, +) }
    public var jogSeconds: Int { segments.filter(\.isJog).map(\.seconds).reduce(0, +) }
    public var repeats: Int { segments.filter(\.isJog).count }

    /// nil when the session doesn't run in `week`.
    public static func make(sessionID: String, session: RunWalkSession, week: Int) -> RunWalkPlan? {
        guard let w = session.weeks.first(where: { $0.week == week }) else { return nil }
        var segments: [Segment] = []
        if w.warmUpWalkMinutes > 0 {
            segments.append(Segment(kind: .warmUp, seconds: w.warmUpWalkMinutes * 60, interval: nil))
        }
        for i in 1...max(w.intervals.repeats, 1) where w.intervals.repeats > 0 {
            segments.append(Segment(kind: .jog, seconds: w.intervals.jogSeconds, interval: i))
            segments.append(Segment(kind: .walk, seconds: w.intervals.walkSeconds, interval: i))
        }
        if w.coolDownWalkMinutes > 0 {
            segments.append(Segment(kind: .coolDown, seconds: w.coolDownWalkMinutes * 60, interval: nil))
        }
        return RunWalkPlan(sessionID: sessionID, name: session.name, week: week, segments: segments)
    }

    /// What the voice says as segment `index` starts.
    public func cue(at index: Int) -> String {
        guard segments.indices.contains(index) else { return "Done. Well walked." }
        let segment = segments[index]
        let length = Self.spoken(segment.seconds)
        switch segment.kind {
        case .warmUp: return "Warm-up walk for \(length). \(Self.effortLine)"
        case .jog: return index <= 1 ? "Jog for \(length). \(Self.effortLine)" : "Jog for \(length)"
        case .walk: return "Walk for \(length)"
        case .coolDown: return "Last one. Cool-down walk for \(length)"
        }
    }

    /// "1 minute", "90 seconds", "2 minutes".
    public static func spoken(_ seconds: Int) -> String {
        if seconds % 60 == 0 {
            let m = seconds / 60
            return m == 1 ? "1 minute" : "\(m) minutes"
        }
        return "\(seconds) seconds"
    }
}
