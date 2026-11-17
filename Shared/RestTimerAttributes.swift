import ActivityKit
import Foundation

/// Shared by the app (starts the activity) and the LiveActivity extension
/// (draws it). Spike S3, board M0-06.
/// `nonisolated` because the targets default to MainActor isolation and
/// ActivityKit encodes these off the main actor.
nonisolated struct RestTimerAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        /// When the rest ends. The widget counts down to this with
        /// `Text(timerInterval:)`, so it keeps ticking while the phone is
        /// locked without the app pushing updates.
        var endsAt: Date
        /// Shown under the countdown, e.g. "Next: Goblet squat, set 2".
        var nextUp: String
        /// UI-11: the weight to dial for the next set; nil (bodyweight) hides "DIAL TO".
        var nextKg: Double? = nil
        /// When the rest began, for the lock-screen progress bar; nil hides the bar.
        var startedAt: Date? = nil
    }

    /// Fixed for the life of the activity, e.g. "Rest".
    var title: String
}
