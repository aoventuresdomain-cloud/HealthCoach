import Foundation

// Board N9 (W1, W5, F1, K3): where tapping a coach notification lands. One
// function for both the real tap (the app's notification delegate) and the
// UI tests' `-openFrom notification:<kind>`, so a test can't route
// differently from the phone. A new Kind won't compile until it has a route.

/// The screen a notification opens.
public enum NotificationDestination: String, Sendable, Equatable {
    /// Today, as it is.
    case today
    /// Today with the Sunday check-in open.
    case sundayPrompt
    /// Meals, on its Shopping section (W5).
    case shopping
    /// Progress with "Ask the coach now" in view.
    case askCoach
    /// Progress with the photo-day camera open (N7, design F1).
    case photoDay
}

public enum NotificationRoute {
    /// Where `kind` lands.
    public static func destination(for kind: CoachNotification.Kind) -> NotificationDestination {
        switch kind {
        case .morningBrief, .leaveNow, .windDown: .today
        case .sundayPrompt: .sundayPrompt
        case .deliveryReminder: .shopping
        case .checkpoint: .askCoach
        case .photoDay: .photoDay
        }
    }

    /// The kind of a delivered notification, from its id ("<kind>-<day>").
    public static func kind(identifier: String) -> CoachNotification.Kind? {
        CoachNotification.Kind.allCases.first { identifier.hasPrefix($0.rawValue + "-") }
    }

    /// The kind named by a UI test's `-openFrom notification:<kind>`.
    public static func kind(openFrom value: String?) -> CoachNotification.Kind? {
        guard let value, value.hasPrefix(openFromPrefix) else { return nil }
        return CoachNotification.Kind(rawValue: String(value.dropFirst(openFromPrefix.count)))
    }

    public static let openFromPrefix = "notification:"
}
