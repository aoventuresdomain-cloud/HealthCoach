import CoachCore
import Foundation

/// C4: the days the owner marked "Social meal" (dinner out, untracked). Days
/// only, stored as "yyyy-MM-dd"; food only, no health data.
@MainActor
final class SocialMealStore {
    static let shared = SocialMealStore()

    private let defaults: UserDefaults
    private let key = "meals.socialDays.v1"

    private init() {
        if LaunchOptions.current.isUITest, let suite = UserDefaults(suiteName: "uitest.social") {
            suite.removePersistentDomain(forName: "uitest.social")
            defaults = suite
        } else {
            defaults = .standard
        }
    }

    /// Start of each marked day, in `calendar`.
    func dates(calendar: Calendar) -> [Date] {
        days.compactMap { key in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        }
    }

    func isSocial(_ date: Date, calendar: Calendar) -> Bool {
        days.contains(Self.dayKey(date, calendar: calendar))
    }

    /// One tap marks the day; another clears it.
    func toggle(_ date: Date, calendar: Calendar) {
        var set = days
        let key = Self.dayKey(date, calendar: calendar)
        if set.contains(key) { set.remove(key) } else { set.insert(key) }
        defaults.set(set.sorted(), forKey: self.key)
    }

    private var days: Set<String> { Set(defaults.stringArray(forKey: key) ?? []) }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
