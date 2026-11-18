import Foundation

public enum MealSlot: String, Codable, Sendable, CaseIterable {
    case breakfast, lunch, dinner, snack
    /// A defined extra, added only to bring a day up into the band.
    case extra
}

/// One meal on the plan, pre-ticked (plan §4.3: "planned meals are
/// pre-ticked"). The app stores any untick; the plan itself never asks.
public struct PlannedMeal: Sendable, Equatable, Identifiable {
    public let slot: MealSlot
    /// The recipe; nil for a box night or an office order.
    public let recipeID: String?
    /// The office order, on an office day's lunch.
    public let lunchOrderID: String?
    public let name: String
    /// One portion: the owner's share.
    public let kcal: Int
    public let protein: Int
    public let isBoxNight: Bool
    public let isOfficeLunch: Bool
    /// Only when the meal has a set time (the Wednesday snack before basketball).
    public let time: TimeOfDay?
    public var ticked = true

    /// Unique within a day (a day can have two extras).
    public var id: String { slot == .extra ? "extra-\(recipeID ?? name)" : slot.rawValue }
}

/// One day's eating.
public struct MealDay: Sendable, Equatable {
    public let date: Date
    public let weekday: Weekday
    public let meals: [PlannedMeal]
    public let target: NutritionContent.DailyTarget
    /// One pre-ticked line with breakfast ("Creatine 5 g, vitamin D 10 µg").
    public let supplements: [String]

    public var kcal: Int { meals.reduce(0) { $0 + $1.kcal } }
    public var protein: Int { meals.reduce(0) { $0 + $1.protein } }
    /// Inside the Advisor's band: kcalMin–kcalMax and at least proteinMin.
    public var withinBand: Bool { (target.kcalMin...target.kcalMax).contains(kcal) && protein >= target.proteinMin }

    public func meal(_ slot: MealSlot) -> PlannedMeal? { meals.first { $0.slot == slot } }
}

/// Board M3-02: the week's meals, planned with no questions. Box nights cover
/// their dinners; office days get a lunch order; everything else rotates
/// through the recipes. Every day lands inside the band (Advisor rule: the
/// week's target ± 150 kcal, never under 1,700, protein ≥ 150 g); the shake replaces the yogurt pot when
/// the day would otherwise be short of protein.
public struct MealPlan: Sendable, Equatable {
    /// Monday to Sunday.
    public let days: [MealDay]

    public func day(_ date: Date, calendar: Calendar = .current) -> MealDay? {
        days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Plans the week starting `monday`. `answers` gives the office days;
    /// `kcalTarget` is this week's calorie target when the rules engine has
    /// moved it (`CalorieTarget.kcal`; the band then matches `CalorieTarget.dayBand`);
    /// `boxNights` defaults to the content's default nights. Deterministic:
    /// the same week always plans the same meals.
    public static func week(monday: Date, content: NutritionContent, lunchOrders: [LunchOrder],
                            answers: WeekAnswers, programmeID: String, kcalTarget: Int? = nil,
                            boxNights: Set<Weekday>? = nil, calendar: Calendar = .current) -> MealPlan {
        guard let base = content.dailyTargets[programmeID] ?? content.dailyTargets.values.first else {
            return MealPlan(days: [])
        }
        // The week's target: the rules engine's when it has one, else the content's.
        let target = kcalTarget.map { base.with(kcal: $0) } ?? base
        let box = boxNights ?? Set(content.boxNight.defaultNights)
        let breakfasts = content.recipes(.breakfast)
        let lunches = content.recipes(.lunch)
        let dinners = content.recipes(.dinner)
        let sundayCook = content.recipes(.sundayCook)
        let start = calendar.startOfDay(for: monday)
        // Rotation offset by week, so consecutive weeks don't repeat day for day.
        let weekIndex = Int((start.timeIntervalSinceReferenceDate / (7 * 86_400)).rounded(.down))

        // Home dinners move on by a whole week's worth each week (N6), so with
        // 3 × home nights of recipes or more no dinner repeats within 3 weeks.
        let homeNights = max(1, Weekday.allCases.filter { $0 != .sunday && !box.contains($0) }.count)

        var days: [MealDay] = []
        var homeDinnerIndex = 0, officeIndex = 0
        for (index, weekday) in Weekday.allCases.enumerated() {
            guard let date = calendar.date(byAdding: .day, value: index, to: start) else { continue }
            let rotation = weekIndex + index
            let isOffice = answers.officeDays.contains(weekday) && weekday != .saturday && weekday != .sunday

            // Dinner: fixed by the day.
            let dinner: PlannedMeal
            if weekday == .sunday, let cook = pick(sundayCook, rotation) {
                dinner = meal(.dinner, cook)
            } else if box.contains(weekday) {
                dinner = PlannedMeal(slot: .dinner, recipeID: nil, lunchOrderID: nil, name: content.boxNight.name,
                                     kcal: content.boxNight.perPortion.kcal, protein: content.boxNight.perPortion.protein,
                                     isBoxNight: true, isOfficeLunch: false, time: nil)
            } else if let home = pick(dinners, weekIndex * homeNights + homeDinnerIndex) {
                homeDinnerIndex += 1
                dinner = meal(.dinner, home)
            } else { continue }

            // Lunch candidates: the office list on an office day, else home lunches.
            let lunchOptions: [PlannedMeal] = isOffice
                ? rotated(lunchOrders, weekIndex + officeIndex).map {
                    PlannedMeal(slot: .lunch, recipeID: nil, lunchOrderID: $0.id, name: "\($0.place): \($0.order)",
                                kcal: $0.kcal, protein: $0.protein, isBoxNight: false, isOfficeLunch: true, time: nil)
                }
                : rotated(lunches, rotation).map { meal(.lunch, $0) }
            if isOffice { officeIndex += 1 }
            let breakfastOptions = rotated(breakfasts, rotation).map { meal(.breakfast, $0) }

            // First combination in rotation order close to the target (± 75 kcal),
            // else the first in the band, else the closest: varied, but the week
            // averages out near the target rather than at the band's edge.
            var combos: [[PlannedMeal]] = []
            for breakfast in breakfastOptions {
                for lunch in lunchOptions {
                    combos.append(withSnack([breakfast, lunch, dinner], weekday: weekday, content: content))
                }
            }
            func day(_ meals: [PlannedMeal]) -> MealDay {
                MealDay(date: date, weekday: weekday, meals: meals, target: target, supplements: [])
            }
            let best = combos.first { day($0).withinBand && abs(day($0).kcal - target.kcal) <= Self.preferredKcalMargin }
                ?? combos.first { day($0).withinBand }
                ?? combos.min {
                    func score(_ d: MealDay) -> Int { abs(d.kcal - target.kcal) + max(0, target.proteinMin - d.protein) * 20 }
                    return score(day($0)) < score(day($1))
                }
            guard let picked = best else { continue }
            let dinnerKind = dinner.isBoxNight ? "box-night" : weekday == .sunday ? "sunday-cook" : "dinner"
            let chosen = withExtras(picked, content: content, target: target, dinnerKind: dinnerKind, rotation: rotation)
            let month = calendar.component(.month, from: date)
            days.append(MealDay(date: date, weekday: weekday, meals: chosen, target: target,
                                supplements: supplementLine(content, month: month).map { [$0] } ?? []))
        }
        return MealPlan(days: days)

        func meal(_ slot: MealSlot, _ recipe: NutritionContent.Recipe) -> PlannedMeal {
            PlannedMeal(slot: slot, recipeID: recipe.id, lunchOrderID: nil, name: recipe.name,
                        kcal: recipe.perPortion.kcal, protein: recipe.perPortion.protein,
                        isBoxNight: false, isOfficeLunch: false, time: nil)
        }
    }

    /// Days are first sought this close to the target, inside the band.
    static let preferredKcalMargin = 75

    /// Closes a day still under the band (a raised weekly target, or
    /// maintenance) with the content's extras, by the Advisor's order: the
    /// protein boost first when planned protein is short, then each step of
    /// `extraRules.order` (one of "a|b|c", rotating by day) until the day is
    /// in the band. Never more than `maxPerDay` extras, nor two of a kind, nor
    /// one that overshoots the band. No extras, or none needed: unchanged.
    static func withExtras(_ meals: [PlannedMeal], content: NutritionContent, target: NutritionContent.DailyTarget,
                           dinnerKind: String, rotation: Int) -> [PlannedMeal] {
        let rules = content.extraRules
        var meals = meals
        var kinds: [String: Int] = [:]
        var added = 0
        func totals(_ m: [PlannedMeal]) -> (kcal: Int, protein: Int) {
            (m.reduce(0) { $0 + $1.kcal }, m.reduce(0) { $0 + $1.protein })
        }
        func applies(_ extra: NutritionContent.Recipe) -> Bool {
            let to = Set(extra.addsTo ?? [])
            return to.contains(dinnerKind) || to.contains("lunch") || to.contains("breakfast") || to.contains("snack")
        }
        /// The meals with `extra` in, or nil if it can't go in.
        func adding(_ extra: NutritionContent.Recipe) -> [PlannedMeal]? {
            guard added < rules.maxPerDay, applies(extra), !meals.contains(where: { $0.recipeID == extra.id }),
                  kinds[extra.extraKind ?? extra.id, default: 0] < rules.maxPerKind else { return nil }
            var next = meals
            if let slot = extra.replaces { next.removeAll { $0.slot == slot } }
            next.append(PlannedMeal(slot: extra.replaces ?? .extra, recipeID: extra.id, lunchOrderID: nil, name: extra.name,
                                    kcal: extra.perPortion.kcal, protein: extra.perPortion.protein,
                                    isBoxNight: false, isOfficeLunch: false, time: nil))
            next.sort { MealSlot.allCases.firstIndex(of: $0.slot)! < MealSlot.allCases.firstIndex(of: $1.slot)! }
            return totals(next).kcal <= target.kcalMax ? next : nil
        }
        func take(_ extra: NutritionContent.Recipe, _ next: [PlannedMeal]) {
            meals = next
            added += 1
            kinds[extra.extraKind ?? extra.id, default: 0] += 1
        }

        guard totals(meals).kcal < target.kcalMin || totals(meals).protein < target.proteinMin else { return meals }
        if totals(meals).protein < rules.proteinFirst.whenPlannedProteinBelow,
           let boost = content.recipe(rules.proteinFirst.extra), let next = adding(boost) {
            take(boost, next)
        }
        for step in rules.steps {
            guard totals(meals).kcal < target.kcalMin else { break }
            let options = step.compactMap(content.recipe)
            guard !options.isEmpty else { continue }
            let start = ((rotation % options.count) + options.count) % options.count
            for extra in options[start...] + options[..<start] {
                if let next = adding(extra) { take(extra, next); break }
            }
        }
        return meals
    }

    /// Adds the snack: the yogurt pot, or the shake when the day would
    /// otherwise be under the protein line (Advisor rule). Wednesday's is at
    /// 17:30, before basketball.
    static func withSnack(_ meals: [PlannedMeal], weekday: Weekday, content: NutritionContent) -> [PlannedMeal] {
        let rule = content.snackRule
        let protein = meals.reduce(0) { $0 + $1.protein }
        guard let pot = content.recipe(rule.default), let shake = content.recipe(rule.replaceWith) else { return meals }
        let snack = protein + pot.perPortion.protein < rule.whenPlannedProteinBelow ? shake : pot
        return meals + [PlannedMeal(slot: .snack, recipeID: snack.id, lunchOrderID: nil, name: snack.name,
                                    kcal: snack.perPortion.kcal, protein: snack.perPortion.protein,
                                    isBoxNight: false, isOfficeLunch: false,
                                    time: weekday == .wednesday ? rule.wednesdayTime : nil)]
    }

    /// "Creatine 5 g, vitamin D 10 µg" for the month, or nil when none apply.
    static func supplementLine(_ content: NutritionContent, month: Int) -> String? {
        let parts = content.supplements.items.filter { $0.months.contains(month) }.compactMap { item -> String? in
            guard let ingredient = content.ingredients[item.ingredient] else { return nil }
            let amount = item.dose ?? NutritionContent.quantity(item.qty, unit: ingredient.unit)
            return "\(item.label) \(amount)"
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private static func pick<T>(_ items: [T], _ index: Int) -> T? {
        items.isEmpty ? nil : items[((index % items.count) + items.count) % items.count]
    }

    /// `items` starting at `index`, wrapping round.
    private static func rotated<T>(_ items: [T], _ index: Int) -> [T] {
        guard !items.isEmpty else { return [] }
        let start = ((index % items.count) + items.count) % items.count
        return Array(items[start...] + items[..<start])
    }
}
