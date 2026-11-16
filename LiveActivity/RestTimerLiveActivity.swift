import ActivityKit
import SwiftUI
import WidgetKit

/// Lock-screen and Dynamic Island rest timer (spike S3, board M0-06).
/// Layouts live in Shared/RestTimerViews.swift so the app can screenshot them.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            RestTimerLockScreenView(
                title: context.attributes.title,
                nextUp: context.state.nextUp,
                endsAt: context.state.endsAt
            )
            .activityBackgroundTint(.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.title, systemImage: "timer")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestCountdown(endsAt: context.state.endsAt)
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
                RestCountdown(endsAt: context.state.endsAt)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                RestCountdown(endsAt: context.state.endsAt)
                    .monospacedDigit()
                    .font(.caption2)
            }
        }
    }
}
