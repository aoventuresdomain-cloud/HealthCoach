import ActivityKit
import Foundation

/// Shared between the app and the LiveActivity widget extension.
/// Lives in Shared/, which belongs to both the app and the widget extension.
struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the rest ends. The widget counts down to this with
        /// `Text(timerInterval:)`, so it keeps ticking while the phone is
        /// locked without the app pushing updates.
        var endsAt: Date
        /// Shown under the countdown, e.g. "Next: Goblet squat, set 2".
        var nextUp: String
    }

    /// Fixed for the life of the activity, e.g. "Rest".
    var title: String
}
