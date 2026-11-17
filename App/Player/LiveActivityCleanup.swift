import ActivityKit
import CoachCore
import Foundation

/// QA-19: a session never survives a relaunch, so every rest or run-walk Live
/// Activity alive at launch is a leftover (a killed app, an earlier UI test).
/// Ending them keeps the lock screen to the session actually running.
enum LiveActivityCleanup {
    /// Call once at launch. Takes the ids first, so an activity a session
    /// starts straight afterwards is never ended by mistake. Activities are
    /// looked up inside the task (same pattern as RestClock.endActivity), so
    /// no Activity value crosses an await (Swift 6 sending check).
    static func endLeftoversAtLaunch() {
        let restIDs = Set(Activity<RestTimerAttributes>.activities.map(\.id))
        let runIDs = Set(Activity<RunWalkAttributes>.activities.map(\.id))
        guard !restIDs.isEmpty || !runIDs.isEmpty else { return }
        Task {
            for live in Activity<RestTimerAttributes>.activities where restIDs.contains(live.id) {
                await live.end(nil, dismissalPolicy: .immediate)
            }
            for live in Activity<RunWalkAttributes>.activities where runIDs.contains(live.id) {
                await live.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
