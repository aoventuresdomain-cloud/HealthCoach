import ActivityKit
import Foundation

/// Shared by the app (starts the activity) and the LiveActivity extension
/// (draws it). Placeholder from M0-02; the S3 spike (M0-06) owns its shape.
/// `nonisolated` because the targets default to MainActor isolation and
/// ActivityKit encodes these off the main actor.
nonisolated struct RestTimerAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        /// When the rest ends; the lock screen counts down to it.
        var endsAt: Date
    }

    var exerciseName: String
}
