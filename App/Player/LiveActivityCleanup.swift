import ActivityKit
import CoachCore
import Foundation

/// QA-19: a session never survives a relaunch, so every rest or run-walk Live
/// Activity alive at launch is a leftover (a killed app, an earlier UI test).
/// Ending them keeps the lock screen to the session actually running.
enum LiveActivityCleanup {
    /// Call once at launch. Takes the list first, so an activity a session
    /// starts straight afterwards is never ended by mistake.
    static func endLeftoversAtLaunch() {
        let rests = Activity<RestTimerAttributes>.activities
        let runs = Activity<RunWalkAttributes>.activities
        guard !rests.isEmpty || !runs.isEmpty else { return }
        Task {
            for activity in rests { await activity.end(nil, dismissalPolicy: .immediate) }
            for activity in runs { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
