import Foundation

/// Board C4: social meals (Advisor ruling, 18 Nov). A social meal counts as
/// 1,000 kcal untracked and replaces that day's planned dinner. The excess
/// over the dinner it replaced comes off the week's other days, at most
/// 100 kcal a day, from carbs and extras, never from protein and never taking
/// a day under 1,700. What doesn't fit is absorbed: nothing carries into next
/// week and nothing is shown. The social day itself saves nothing up: its
/// other meals stay as planned and it is exempt from the band. Two a week by
/// default; a third is allowed but flagged in the Claude summary.
public enum SocialMeals {
    public static let kcal = 1_000
    public static let perWeek = 2
    /// The most taken off any other day.
    public static let maxTrimPerDayKcal = 100
    public static let trimName = "Lighter carbs (social meal this week)"

    /// "1 of 2"; a third reads "3 of 2" and is flagged.
    public struct Count: Sendable, Equatable {
        public let used: Int
        public let allowance: Int
        public var text: String { "\(used) of \(allowance)" }
        /// Over the allowance: allowed, but the summary says so.
        public var flagged: Bool { used > allowance }
    }

    public static func count(_ dates: [Date], weekOf monday: Date, calendar: Calendar = .current) -> Count {
        let start = calendar.startOfDay(for: monday)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let days = Set(dates.filter { $0 >= start && $0 < end }.map { calendar.startOfDay(for: $0) })
        return Count(used: days.count, allowance: perWeek)
    }
}

extension MealPlan {
    /// The week with social meals on `dates` (one per day; extra dates on the
    /// same day count once). Each replaces that day's dinner; the excess is
    /// trimmed from the other days, after the social day first.
    public func withSocialMeals(_ dates: [Date], calendar: Calendar = .current) -> MealPlan {
        let socialDays = Set(dates.map { calendar.startOfDay(for: $0) })
        guard !socialDays.isEmpty else { return self }
        var days = self.days
        var excess = 0
        for i in days.indices where socialDays.contains(calendar.startOfDay(for: days[i].date)) {
            let replaced = days[i].meal(.dinner)?.kcal ?? 0
            excess += max(0, SocialMeals.kcal - replaced)
            let social = PlannedMeal(slot: .dinner, recipeID: nil, lunchOrderID: nil, name: "Social meal",
                                     kcal: SocialMeals.kcal, protein: 0, isBoxNight: false, isOfficeLunch: false,
                                     time: nil, isSocial: true)
            days[i] = days[i].replacing(.dinner, with: social)
        }
        // Other days, the ones after the first social meal first, then earlier ones.
        let first = socialDays.min()!
        let others = days.indices.filter { !socialDays.contains(calendar.startOfDay(for: days[$0].date)) }
            .sorted { (days[$0].date > first ? 0 : 1, days[$0].date) < (days[$1].date > first ? 0 : 1, days[$1].date) }
        guard !others.isEmpty else { return MealPlan(days: days) }
        // Spread evenly, at most 100 a day, never under the floor.
        var remaining = excess
        for (n, i) in others.enumerated() where remaining > 0 {
            let share = Int((Double(remaining) / Double(others.count - n)).rounded(.up))
            let room = max(0, days[i].kcal - days[i].target.kcalFloor)
            let trim = min(SocialMeals.maxTrimPerDayKcal, share, room)
            guard trim > 0 else { continue }
            days[i] = days[i].adding(PlannedMeal(slot: .extra, recipeID: nil, lunchOrderID: nil, name: SocialMeals.trimName,
                                                 kcal: -trim, protein: 0, isBoxNight: false, isOfficeLunch: false,
                                                 time: nil))
            remaining -= trim
        }
        return MealPlan(days: days)
    }
}

extension MealDay {
    /// A social meal is on this day: it is exempt from the band.
    public var isSocial: Bool { meals.contains { $0.isSocial } }

    func replacing(_ slot: MealSlot, with meal: PlannedMeal) -> MealDay {
        var copy = self
        copy.meals = meals.map { $0.slot == slot ? meal : $0 }
        return copy
    }

    func adding(_ meal: PlannedMeal) -> MealDay {
        var copy = self
        copy.meals = meals + [meal]
        return copy
    }
}
