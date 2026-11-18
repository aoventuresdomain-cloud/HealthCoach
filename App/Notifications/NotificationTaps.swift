import CoachCore
import Foundation
import Observation
import UserNotifications

/// Board N9: opens the right screen when a coach notification is tapped. The
/// real tap and the UI tests' `-openFrom notification:<kind>` both go through
/// `NotificationRoute.destination(for:)` (CoachCore), so they can't differ.
/// The views read `pending` and clear it once they've shown the screen.
@Observable @MainActor
final class NotificationTaps: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationTaps()

    /// The screen a tap asked for, until a view has opened it.
    var pending: NotificationDestination?

    /// Called once at launch. UI tests never touch the real notification centre;
    /// they start from `-openFrom` instead.
    func install(options: LaunchOptions = .current) {
        if options.isUITest {
            if let kind = NotificationRoute.kind(openFrom: options.openFrom) { open(kind) }
        } else {
            UNUserNotificationCenter.current().delegate = self
        }
    }

    func open(_ kind: CoachNotification.Kind) {
        pending = NotificationRoute.destination(for: kind)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let id = response.notification.request.identifier
        guard let kind = NotificationRoute.kind(identifier: id) else { return }
        await MainActor.run { open(kind) }
    }
}
