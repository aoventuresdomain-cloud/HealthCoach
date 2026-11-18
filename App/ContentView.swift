import CoachCore
import SwiftData
import SwiftUI

/// Root: onboarding until the profile is confirmed, then Today (board M1-04,
/// M1-05). The `-screenshot` spike modes still open straight on their state.
struct ContentView: View {
    var body: some View {
        switch ScreenshotMode.current {
        case .liveActivity:
            NavigationStack { LiveActivityPreviewView() }
        case let mode?:
            NavigationStack { SpikeTestsView(screenshot: mode) }
        case nil:
            // UI-1: one dark look everywhere, green accent (rest and walk stay blue).
            RootView()
                .preferredColorScheme(.dark)
                .tint(.go)
        }
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var state = LoadState.loading
    @State private var playing: SessionLaunch?

    private enum LoadState {
        case loading
        case ready(ContentLibrary, Programme, Profile)
        case failed(String)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case let .failed(message):
                ContentUnavailableView("HealthCoach can't start", systemImage: "exclamationmark.triangle", description: Text(message))
                    .accessibilityIdentifier("root.error")
            case let .ready(content, programme, profile):
                if profile.confirmed {
                    // UI-6: Today, Meals and Progress as tabs. Always opens on Today;
                    // sessions stay full-screen covers, so no tab bar mid-session.
                    TabView {
                        Tab("Today", systemImage: "sun.max") {
                            NavigationStack {
                                TodayView(content: content, programme: programme, profile: profile) { slot, week, recovery in
                                    playing = SessionLaunch.make(slot: slot, week: week, recovery: recovery,
                                                                 content: content, programme: programme, profile: profile,
                                                                 history: (try? SessionLogStore(context: context).all()) ?? [])
                                }
                            }
                        }
                        Tab("Meals", systemImage: "fork.knife") {
                            NavigationStack {
                                MealsHubView(content: content, profile: profile)
                            }
                        }
                        Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                            NavigationStack {
                                ProgressScreen(content: content, programme: programme, profile: profile)
                            }
                        }
                    }
                    .tabBarMinimizeBehavior(.onScrollDown)
                    // UI-2: Start gets the medium impact as the session opens.
                    .sensoryFeedback(trigger: playing != nil) { _, started in started ? .impact(weight: .medium) : nil }
                    .fullScreenCover(item: $playing) { launch in
                        launch.view { log in
                            do {
                                try SessionLogStore(context: context).save(log)
                            } catch {
                                // Logging failed: the session still ends; nothing else depends on it in M1.
                            }
                            playing = nil
                        }
                        .preferredColorScheme(.dark)
                    }
                } else {
                    OnboardingFlow(profile: profile, programme: programme,
                                   skipSystemPrompts: LaunchOptions.current.isUITest) { confirmed in
                        save(confirmed, content: content, programme: programme)
                    }
                }
            }
        }
        .task { load() }
    }

    private func load() {
        do {
            let content = try BundledContent.load()
            let profile = try ProfileStore(context: context).load() ?? Profile()
            guard let programme = content.programme(for: profile, on: AppClock.now(), calendar: .coach) else {
                state = .failed("No programme called \(profile.programme.programmeID) in this build.")
                return
            }
            state = .ready(content, programme, profile)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func save(_ profile: Profile, content: ContentLibrary, programme: Programme) {
        do {
            try ProfileStore(context: context).save(profile)
            state = .ready(content, programme, profile)
        } catch {
            state = .failed("Couldn't save your answers: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
