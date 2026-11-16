import ActivityKit
import Foundation

/// Run-walk Live Activity (board M1-07, design screen 11): mirrors the
/// run-walk screen on the lock screen so the phone can stay in a pocket.
/// Shared by the app (starts it) and the LiveActivity extension (draws it).
nonisolated struct RunWalkAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        /// "JOG", "WALK", "WARM-UP", "COOL-DOWN".
        var label: String
        var isJog: Bool
        /// When this segment ends; the widget counts down to it.
        var endsAt: Date
        /// Set while paused: the seconds left, shown still.
        var pausedRemaining: Int?
        /// "Then walk 1:00".
        var nextUp: String
        /// "Interval 4 of 10".
        var progress: String
    }

    /// "Run-walk · Week 1".
    var title: String
}
