import CoachCore
import Foundation

/// N1: the check-ins, one per week, keyed by the Monday they plan. Kept on the
/// phone; the coach summary reads them, nothing else leaves the device.
@MainActor
final class CheckInStore {
    static let shared = CheckInStore()

    private let defaults: UserDefaults
    private let key = "checkIn.weeks.v2"

    private init() {
        // UI tests start unanswered, like the Sunday prompt.
        if LaunchOptions.current.isUITest, let suite = UserDefaults(suiteName: "uitest.checkIn") {
            suite.removePersistentDomain(forName: "uitest.checkIn")
            defaults = suite
        } else {
            defaults = .standard
        }
    }

    func checkIn(weekStarting monday: Date, calendar: Calendar) -> CheckIn? {
        stored[SocialMealStore.dayKey(monday, calendar: calendar)]
    }

    func hasCheckedIn(weekStarting monday: Date, calendar: Calendar) -> Bool {
        checkIn(weekStarting: monday, calendar: calendar) != nil
    }

    func save(_ checkIn: CheckIn, weekStarting monday: Date, calendar: Calendar) {
        var all = stored
        all[SocialMealStore.dayKey(monday, calendar: calendar)] = checkIn
        stored = all
    }

    /// Every check-in, oldest first, for the core rules (pain swaps, easing, summary).
    var all: [CheckIn] { stored.values.sorted { $0.date < $1.date } }

    /// Keyed "yyyy-MM-dd" (the Monday).
    private var stored: [String: CheckIn] {
        get {
            guard let data = defaults.data(forKey: key) else { return [:] }
            return (try? JSONDecoder().decode([String: CheckIn].self, from: data)) ?? [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: key) }
        }
    }
}
