import SwiftUI

@main
struct HealthCoachApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Plan §4.1: every open checks registered alarms against the plan
            // and re-sets any that are missing (spike S1b). No background job.
            guard phase == .active else { return }
            Task { _ = await AlarmKitSpike.shared.reconcileStatus() }
        }
    }
}
