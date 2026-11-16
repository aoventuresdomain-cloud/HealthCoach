import CoachCore
import SwiftUI

/// M0 skeleton screen. The Today screen replaces it in M1; the Spike tests
/// screen (board M0-11) hangs off it until Gate 1.
struct ContentView: View {
    var body: some View {
        switch ScreenshotMode.current {
        case .liveActivity:
            NavigationStack { LiveActivityPreviewView() }
        case let mode?:
            NavigationStack { SpikeTestsView(screenshot: mode) }
        case nil:
            home
        }
    }

    private var home: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("HealthCoach")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("home.title")
                Text("Core schema v\(CoachCore.schemaVersion)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if SpikeTests.isEnabled {
                    NavigationLink("Spike tests") { SpikeTestsView() }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 24)
                        .accessibilityIdentifier("home.spikeTests")
                }
                if LaunchOptions.current.isUITest {
                    UITestStatus()
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
