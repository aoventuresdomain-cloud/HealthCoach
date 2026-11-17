import CoachCore
import Foundation
import UserNotifications

/// Board M2-05: keeps the next 14 days of coach notifications pending, built
/// by `NotificationPlanner` (which never puts one in quiet hours, 22:30–06:00).
/// Runs on every open and after the Sunday prompt, like the wake alarms.
/// Local notifications only; nothing leaves the phone.
@MainActor
final class CoachNotifier {
    static let shared = CoachNotifier()

    /// What the last reschedule planned; the UI test debug line reads it.
    private(set) var lastPlanned: [CoachNotification]?

    private let center: UNUserNotificationCenter?

    private init() {
        // UI tests plan but never touch the real notification centre.
        center = LaunchOptions.current.isUITest ? nil : .current()
    }

    func reschedule(profile: Profile, history: [SessionLog] = [], now: Date = AppClock.now(),
                    answers: WeekAnswersStore = .shared) async {
        guard let content = try? BundledContent.load(),
              let programme = content.programmes[profile.programme.programmeID] else {
            // A plan that didn't load leaves the pending ones as they were.
            return
        }
        let calendar = Calendar.coach
        let planned = NotificationPlanner.plan(
            now: now, programme: programme, profile: profile,
            answers: { answers.answers(weekStarting: $0, calendar: calendar) },
            dropping: Set(programme.droppedSessions(history: history)), calendar: calendar)
        lastPlanned = planned

        guard let center else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            // Onboarding asks; without permission there is nothing to schedule.
            return
        }
        // Replace only ours: every id starts with a kind name.
        let kinds = CoachNotification.Kind.allCases.map(\.rawValue)
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { id in kinds.contains { id.hasPrefix($0 + "-") } }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for item in planned {
            let body = UNMutableNotificationContent()
            body.title = item.title
            body.body = item.body
            body.sound = .default
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            // One failed add leaves the rest scheduled; the next open tries again.
            try? await center.add(UNNotificationRequest(identifier: item.id, content: body, trigger: trigger))
        }
    }
}
