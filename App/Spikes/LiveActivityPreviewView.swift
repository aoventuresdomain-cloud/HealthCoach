import SwiftUI

/// Draws the rest-timer Live Activity layouts in-app for CI screenshots
/// (`-screenshot live-activity`). Same views as the widget, counting live.
struct LiveActivityPreviewView: View {
    @State private var endsAt = Date.now.addingTimeInterval(TimeInterval(RestTimerSpike.restSeconds))

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                caption("Lock screen")
                RestTimerLockScreenView(title: "Rest", nextUp: "Next: Goblet squat, set 2", endsAt: endsAt)
                    .background(.black.opacity(0.8), in: .rect(cornerRadius: 22))

                caption("Dynamic Island, expanded")
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Rest", systemImage: "timer").font(.headline)
                        Spacer()
                        RestCountdown(endsAt: endsAt).font(.title2.monospacedDigit().bold())
                    }
                    Text("Next: Goblet squat, set 2")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .foregroundStyle(.white)
                .background(.black, in: .rect(cornerRadius: 40))

                caption("Dynamic Island, compact")
                HStack {
                    Image(systemName: "timer")
                    Spacer()
                    RestCountdown(endsAt: endsAt).monospacedDigit().frame(maxWidth: 44)
                }
                .padding(.horizontal, 16)
                .frame(width: 250, height: 37)
                .foregroundStyle(.white)
                .background(.black, in: .capsule)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Live Activity preview")
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
    }
}

#Preview {
    NavigationStack { LiveActivityPreviewView() }
}
