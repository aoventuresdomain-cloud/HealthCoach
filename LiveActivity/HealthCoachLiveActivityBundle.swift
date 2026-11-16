import SwiftUI
import WidgetKit

@main
struct HealthCoachLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
        RunWalkLiveActivity()
    }
}
