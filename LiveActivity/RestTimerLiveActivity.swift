import ActivityKit
import SwiftUI
import WidgetKit

/// Lock-screen and Dynamic Island rest timer (spike S3, board M0-06).
/// Register in the widget bundle: `RestTimerLiveActivity()`.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            LockScreenRestView(context: context)
                .activityBackgroundTint(.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.title, systemImage: "timer")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(endsAt: context.state.endsAt)
                        .font(.title2.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.nextUp)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Countdown(endsAt: context.state.endsAt)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Countdown(endsAt: context.state.endsAt)
                    .monospacedDigit()
                    .font(.caption2)
            }
        }
    }
}

private struct LockScreenRestView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title)
                    .font(.headline)
                Text(context.state.nextUp)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Countdown(endsAt: context.state.endsAt)
                .font(.system(size: 44, weight: .bold).monospacedDigit())
        }
        .padding()
        .foregroundStyle(.white)
    }
}

/// Counts down to `endsAt` and stops at 0:00 rather than counting up.
private struct Countdown: View {
    let endsAt: Date

    var body: some View {
        // Guard against an end date already in the past: a reversed range traps.
        let start = min(Date.now, endsAt)
        Text(timerInterval: start...endsAt, countsDown: true, showsHours: false)
            .multilineTextAlignment(.trailing)
    }
}
