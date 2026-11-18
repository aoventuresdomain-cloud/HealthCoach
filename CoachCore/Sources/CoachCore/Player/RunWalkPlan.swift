import Foundation

/// One week's run-walk as a list of timed segments (board M1-07): warm-up
/// walk → jog/walk intervals → cool-down walk, with what the voice says at
/// each change. All lengths come from the programme data.
public struct RunWalkPlan: Equatable, Sendable {
    public let sessionID: String
    public let name: String
    public let week: Int
    public let segments: [Segment]
    /// N10: the named loop closest to this session's distance (`naming(_:)`).
    public private(set) var loop: RunLoops.Loop? = nil

    public struct Segment: Equatable, Sendable {
        public enum Kind: String, Sendable { case warmUp, jog, walk, coolDown, briskWalk }
        public let kind: Kind
        public let seconds: Int
        /// 1-based jog number for intervals; nil for warm-up and cool-down.
        public let interval: Int?

        public var isJog: Bool { kind == .jog }
    }

    /// The effort, set once by the first cue and repeated on screen (design M1-03).
    public static let effortLine = "Easy pace: you could chat."

    /// Pace assumptions for `estimatedKm` (km/h): easy jog, recovery walk,
    /// brisk walk. Rough on purpose: only used to pick a loop.
    public static let jogKmh = 8.0, walkKmh = 5.0, briskWalkKmh = 6.0

    /// About how far the session goes, to the nearest 0.1 km.
    public var estimatedKm: Double {
        let km = segments.reduce(0.0) { total, segment in
            let kmh = switch segment.kind {
            case .jog: Self.jogKmh
            case .briskWalk: Self.briskWalkKmh
            case .walk, .warmUp, .coolDown: Self.walkKmh
            }
            return total + kmh * Double(segment.seconds) / 3600
        }
        return (km * 10).rounded() / 10
    }

    /// N10: this plan with the route's loop closest to `estimatedKm`; unchanged
    /// when the route has no loops file.
    public func naming(_ loops: RunLoops?) -> RunWalkPlan {
        var named = self
        named.loop = loops?.closest(toKm: estimatedKm)
        return named
    }

    /// "Long Water loop, about 2 km". nil without a loop.
    public var loopLine: String? {
        guard let loop else { return nil }
        let km = loop.distanceKm.rounded() == loop.distanceKm ? String(Int(loop.distanceKm)) : String(format: "%.1f", loop.distanceKm)
        return "\(loop.name), about \(km) km"
    }

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

    /// Brisk-walk length bounds (Advisor N1 condition c).
    public static let briskWalkMinutes = 20...30

    /// N1 condition (c): the week's run-walk as one brisk walk, its planned
    /// length held to 20-30 minutes, for knee or back pain. nil when the
    /// session doesn't run in `week`.
    public static func briskWalk(sessionID: String, session: RunWalkSession, week: Int) -> RunWalkPlan? {
        guard let w = session.weeks.first(where: { $0.week == week }) else { return nil }
        let minutes = min(max(w.durationMinutes, briskWalkMinutes.lowerBound), briskWalkMinutes.upperBound)
        return RunWalkPlan(sessionID: sessionID, name: "Brisk walk", week: week,
                           segments: [Segment(kind: .briskWalk, seconds: minutes * 60, interval: nil)])
    }

    /// The run-walk for `week` under the pain areas in force: a brisk walk
    /// for knee or back, otherwise as planned.
    public static func make(sessionID: String, session: RunWalkSession, week: Int,
                            painAreas: Set<PainArea>) -> RunWalkPlan? {
        PainSwaps.walksInsteadOfRunning(painAreas)
            ? briskWalk(sessionID: sessionID, session: session, week: week)
            : make(sessionID: sessionID, session: session, week: week)
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
        case .briskWalk: return "Brisk walk for \(length). Walk tall, quick steps, no jogging."
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
