import Foundation

/// One finished (or abandoned) session, as logged by the player. Owned by the
/// Planner Engineer; progression (M1-08) reads these. Stored by the app.
public struct SessionLog: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var programmeID: String
    /// Key into `Programme.sessions` ("upper-a").
    public var sessionID: String
    /// Programme week, 1-based.
    public var week: Int
    public var startedAt: Date
    public var finishedAt: Date?
    /// The answer to "Still sore from last time?" on Today; nil = not asked or ignored (= fine).
    public var recovery: RecoveryCheck?
    public var sets: [SetLog]

    public init(id: UUID = UUID(), programmeID: String, sessionID: String, week: Int,
                startedAt: Date, finishedAt: Date? = nil, recovery: RecoveryCheck? = nil, sets: [SetLog] = []) {
        self.id = id
        self.programmeID = programmeID
        self.sessionID = sessionID
        self.week = week
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.recovery = recovery
        self.sets = sets
    }

    public var isComplete: Bool { finishedAt != nil }
}

public enum RecoveryCheck: String, Codable, Sendable, CaseIterable {
    case fine, sore
}

/// One working set. Warm-ups aren't logged.
public struct SetLog: Codable, Sendable, Equatable {
    /// The exercise actually done (after any autoSwap or graduate).
    public var exercise: String
    /// 0-based set number within the item.
    public var setIndex: Int
    /// Reps done (tap-counted), or nil for a timed item.
    public var reps: Int?
    /// Seconds held, for timed items.
    public var seconds: Int?
    /// Per dumbbell; nil = bodyweight.
    public var kg: Double?
    /// Tapped "done as prescribed": reps or seconds hit the top of today's target.
    public var asPrescribed: Bool
    /// Lowered over 3 seconds (tempo step of reps-tempo rules).
    public var slowTempo: Bool

    public init(exercise: String, setIndex: Int, reps: Int? = nil, seconds: Int? = nil,
                kg: Double? = nil, asPrescribed: Bool, slowTempo: Bool = false) {
        self.exercise = exercise
        self.setIndex = setIndex
        self.reps = reps
        self.seconds = seconds
        self.kg = kg
        self.asPrescribed = asPrescribed
        self.slowTempo = slowTempo
    }
}
