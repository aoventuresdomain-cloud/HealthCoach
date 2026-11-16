import ActivityKit
import SwiftUI
import WidgetKit

/// Lock-screen and Dynamic Island run-walk interval (board M1-07).
struct RunWalkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunWalkAttributes.self) { context in
            RunWalkLockScreenView(title: context.attributes.title, state: context.state)
                .activityBackgroundTint(.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.label)
                        .font(.title2.bold())
                        .foregroundStyle(context.state.isJog ? .green : .blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RunWalkClock(state: context.state)
                        .font(.title2.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.progress) · \(context.state.nextUp)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: context.state.isJog ? "figure.run" : "figure.walk")
                    .foregroundStyle(context.state.isJog ? .green : .blue)
            } compactTrailing: {
                RunWalkClock(state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: context.state.isJog ? "figure.run" : "figure.walk")
                    .foregroundStyle(context.state.isJog ? .green : .blue)
            }
        }
    }
}
