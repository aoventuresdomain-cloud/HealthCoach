import SwiftData
import SwiftUI
import UIKit

@main
struct HealthCoachApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        let options = LaunchOptions.current
        do {
            container = try AppStore.makeContainer(options: options)
        } catch {
            // The store can't open: nothing sensible to run without it.
            fatalError("Couldn't open the HealthCoach store: \(error)")
        }
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
            Task { _ = await AlarmKitSpike.shared.reconcileStatus() }
        }
    }
}
