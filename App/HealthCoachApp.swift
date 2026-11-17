import CoachCore
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
            CoachBlockStore.resetForUITest()
        }
        if let name = options.fixture {
            do {
                let fixture = try Fixture.load(named: name)
                try ProfileStore(context: container.mainContext).save(fixture.profile)
                let logs = SessionLogStore(context: container.mainContext)
                for log in fixture.logs { try logs.save(log) }
                try fixture.applyWeekAnswers(to: WeekAnswersStore())
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
            // An unreadable log store means a normal week, never a missing alarm.
            let history = (try? SessionLogStore(context: container.mainContext).all()) ?? []
            Task {
                if let profile, WakeAlarms.shared.isActive(profile: profile) {
                    // Board M2-02: the planner's 14 days of wake alarms.
                    await WakeAlarms.shared.reconcile(profile: profile, history: history)
                    // Board M2-03: on a run day, the forecast may swap the run indoors.
                    await MorningWeather.shared.check(
                        profile: profile, completed: SessionLog.sessionIDs(in: history, weekOf: AppClock.now()))
                } else {
                    _ = await AlarmKitSpike.shared.reconcileStatus()
                }
                // Board M2-05: the next 14 days of notifications, never in quiet hours.
                if let profile, profile.programme.startDate != nil {
                    await CoachNotifier.shared.reschedule(profile: profile, history: history)
                }
                // Board M2-04: weight trend and steps, read-only, after onboarding.
                if profile?.confirmed == true {
                    await BodyStats.shared.refresh()
                }
            }
        }
    }
}
