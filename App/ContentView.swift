import CoachCore
import SwiftUI

/// M0 skeleton screen. The Today screen replaces it in M1; the Spike tests
/// screen (board M0-11) hangs off it until Gate 1.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("HealthCoach")
                .font(.largeTitle.bold())
            Text("Core schema v\(CoachCore.schemaVersion)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
