import CoachCore
import Foundation

/// What the owner changed on the meal and shopping lists (M3-04). Planned
/// meals are pre-ticked; only unticks are stored. Staples stay ticked once
/// ticked; other shopping ticks last for their week. Food only, no health data.
@MainActor
final class MealTicks {
    static let shared = MealTicks()

    private let defaults: UserDefaults
    private let mealsKey = "meals.unticked.v1"
    private let everUntickedKey = "meals.everUnticked.v1"
    private let staplesKey = "shopping.tickedStaples.v1"
    private let shoppingKey = "shopping.ticked.v1"

    private init() {
        if LaunchOptions.current.isUITest, let suite = UserDefaults(suiteName: "uitest.meals") {
            suite.removePersistentDomain(forName: "uitest.meals")
            defaults = suite
        } else {
            defaults = .standard
        }
    }

    // MARK: Meals

    static func mealKey(_ date: Date, _ mealID: String, calendar: Calendar) -> String {
        "\(dayKey(date, calendar: calendar))|\(mealID)"
    }

    func isTicked(_ meal: PlannedMeal, on date: Date, calendar: Calendar) -> Bool {
        !unticked.contains(Self.mealKey(date, meal.id, calendar: calendar))
    }

    func setTicked(_ ticked: Bool, _ meal: PlannedMeal, on date: Date, calendar: Calendar) {
        var set = unticked
        let key = Self.mealKey(date, meal.id, calendar: calendar)
        if ticked { set.remove(key) } else { set.insert(key) }
        defaults.set(Array(set), forKey: mealsKey)
        if !ticked { defaults.set(true, forKey: everUntickedKey) }
    }

    /// UI-12: the "untick anything you skipped" footer shows until the first untick, then never again.
    var hasEverUnticked: Bool { defaults.bool(forKey: everUntickedKey) }

    private var unticked: Set<String> { Set(defaults.stringArray(forKey: mealsKey) ?? []) }

    // MARK: Shopping

    var tickedStaples: Set<String> { Set(defaults.stringArray(forKey: staplesKey) ?? []) }

    func isTicked(_ item: ShoppingItem, week monday: Date, calendar: Calendar) -> Bool {
        item.isStaple ? tickedStaples.contains(item.id) : weekTicks(monday, calendar: calendar).contains(item.id)
    }

    func setTicked(_ ticked: Bool, _ item: ShoppingItem, week monday: Date, calendar: Calendar) {
        if item.isStaple {
            var set = tickedStaples
            if ticked { set.insert(item.id) } else { set.remove(item.id) }
            defaults.set(Array(set), forKey: staplesKey)
        } else {
            var set = weekTicks(monday, calendar: calendar)
            if ticked { set.insert(item.id) } else { set.remove(item.id) }
            // Only this week's ticks are kept.
            defaults.set([Self.dayKey(monday, calendar: calendar): Array(set)], forKey: shoppingKey)
        }
    }

    private func weekTicks(_ monday: Date, calendar: Calendar) -> Set<String> {
        let all = defaults.dictionary(forKey: shoppingKey) as? [String: [String]] ?? [:]
        return Set(all[Self.dayKey(monday, calendar: calendar)] ?? [])
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
