import SwiftData
import SwiftUI
import UIKit

@main
struct HealthCoachApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        let options = LaunchOptions.current
        // Never crashes: a store that won't open is kept aside and the app
        // starts fresh (AppStore.recovery says so).
        container = AppStore.open(options: options)
        if options.isUITest {
            UIView.setAnimationsEnabled(false)
        }
        if let name = options.fixture {
            do {
                try ProfileStore(context: container.mainContext).save(Fixture.load(named: name).profile)
            } catch {
                fatalError("UI test fixture \(name) failed: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            // Plan §4.1: every open checks registered alarms against the plan
            // and re-sets any that are missing (spike S1b). No background job.
            guard phase == .active else { return }
            let profile = try? ProfileStore(context: container.mainContext).load()
            Task {
                if let profile, WakeAlarms.shared.isActive(profile: profile) {
                    // Board M2-02: the planner's 14 days of wake alarms.
                    await WakeAlarms.shared.reconcile(profile: profile)
                } else {
                    _ = await AlarmKitSpike.shared.reconcileStatus()
                }
            }
        }
    }
}
