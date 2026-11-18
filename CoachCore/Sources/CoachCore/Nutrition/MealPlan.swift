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
    /// C4: a social meal, 1,000 kcal untracked, in place of the planned dinner.
    public var isSocial = false

    /// Unique within a day (a day can have two extras).
    public var id: String { slot == .extra ? "extra-\(recipeID ?? name)" : slot.rawValue }
}

/// One day's eating.
public struct MealDay: Sendable, Equatable {
    public let date: Date
    public let weekday: Weekday
    public internal(set) var meals: [PlannedMeal]
    public let target: NutritionContent.DailyTarget
    /// One pre-ticked line with breakfast ("Creatine 5 g, vitamin D 10 µg").
    public let supplements: [String]
    /// C3: what this day was planned towards: above the week's target on a
    /// training day, below it on a rest day, so the week averages the target.
    /// The band stays the week's target ± 150. nil: the week's target.
    public var aimKcal: Int? = nil

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
    /// `trainingDays` the days with a session (C3: they eat more, rest days
    /// less, and the week still averages the target);
    /// `kcalTarget` is this week's calorie target when the rules engine has
    /// moved it (`CalorieTarget.kcal`; the band then matches `CalorieTarget.dayBand`);
    /// `boxNights` defaults to the content's default nights. `dislikes(date)`
    /// gives that day's dislike list (N3: `Profile.dislikes(on:)`, so an edit
    /// applies from tomorrow); no planned recipe, extra, snack or lunch order
    /// ever matches it. Deterministic: the same week always plans the same meals.
    public static func week(monday: Date, content: NutritionContent, lunchOrders: [LunchOrder],
                            answers: WeekAnswers, programmeID: String, kcalTarget: Int? = nil,
                            trainingDays: Set<Weekday> = [],
                            boxNights: Set<Weekday>? = nil,
                            dislikes: (Date) -> [String] = { _ in [] },
                            calendar: Calendar = .current) -> MealPlan {
        guard let base = content.dailyTargets[programmeID] ?? content.dailyTargets.values.first else {
            return MealPlan(days: [])
        }
        // The week's target: the rules engine's when it has one, else the content's.
        let target = kcalTarget.map { base.with(kcal: $0) } ?? base
        let box = boxNights ?? Set(content.boxNight.defaultNights)
        let start = calendar.startOfDay(for: monday)
        // Rotation offset by week, so consecutive weeks don't repeat day for day.
        let weekIndex = Int((start.timeIntervalSinceReferenceDate / (7 * 86_400)).rounded(.down))

        // Home dinners move on by a whole week's worth each week (N6), so with
        // 3 × home nights of recipes or more no dinner repeats within 3 weeks.
        let homeNights = max(1, Weekday.allCases.filter { $0 != .sunday && !box.contains($0) }.count)

        // C3: only lean when the caller says which days train; else every day aims at the target.
        let aims = trainingDays.isEmpty ? [:] : dayAims(target: target, trainingDays: trainingDays)
        var planned: [(date: Date, weekday: Weekday, meals: [PlannedMeal], dinnerKind: String, rotation: Int)] = []
        var homeDinnerIndex = 0, officeIndex = 0
        var weekDislikes: [String] = []
        for (index, weekday) in Weekday.allCases.enumerated() {
            guard let date = calendar.date(byAdding: .day, value: index, to: start) else { continue }
            let rotation = weekIndex + index
            // N3: the day's content without anything disliked that day.
            let avoid = dislikes(date)
            weekDislikes += avoid
            let content = content.excluding(dislikes: avoid)
            let lunchOrders = lunchOrders.filter { !$0.isDisliked(by: avoid) }
            let breakfasts = content.recipes(.breakfast)
            let lunches = content.recipes(.lunch)
            let dinners = content.recipes(.dinner)
            let sundayCook = content.recipes(.sundayCook)
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

            // Lunch candidates: the office list on an office day, else home
            // lunches. N3: an office day with every order disliked takes a home
            // lunch to work instead.
            let lunchOptions: [PlannedMeal] = isOffice && !lunchOrders.isEmpty
                ? rotated(lunchOrders, weekIndex + officeIndex).map {
                    PlannedMeal(slot: .lunch, recipeID: nil, lunchOrderID: $0.id, name: "\($0.place): \($0.order)",
                                kcal: $0.kcal, protein: $0.protein, isBoxNight: false, isOfficeLunch: true, time: nil)
                }
                : rotated(lunches, rotation).map { meal(.lunch, $0) }
            if isOffice && !lunchOrders.isEmpty { officeIndex += 1 }
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
            let aim = aims[weekday] ?? target.kcal
            let best = combos.first { day($0).withinBand && abs(day($0).kcal - aim) <= Self.preferredKcalMargin }
                ?? combos.filter { day($0).withinBand }.min { abs(day($0).kcal - aim) < abs(day($1).kcal - aim) }
                ?? combos.min {
                    func score(_ d: MealDay) -> Int { abs(d.kcal - aim) + max(0, target.proteinMin - d.protein) * 20 }
                    return score(day($0)) < score(day($1))
                }
            guard let picked = best else { continue }
            let dinnerKind = dinner.isBoxNight ? "box-night" : weekday == .sunday ? "sunday-cook" : "dinner"
            let chosen = withExtras(picked, content: content, target: target, aim: aims[weekday],
                                    dinnerKind: dinnerKind, rotation: rotation)
            planned.append((date, weekday, chosen, dinnerKind, rotation))
        }
        if !aims.isEmpty {
            // Extras moved between days avoid every dislike of the week.
            balance(&planned, content: content.excluding(dislikes: weekDislikes), target: target,
                    trainingDays: trainingDays)
        }
        return MealPlan(days: planned.map { day in
            let month = calendar.component(.month, from: day.date)
            return MealDay(date: day.date, weekday: day.weekday, meals: day.meals, target: target,
                           supplements: supplementLine(content, month: month).map { [$0] } ?? [],
                           aimKcal: aims[day.weekday])
        })

        func meal(_ slot: MealSlot, _ recipe: NutritionContent.Recipe) -> PlannedMeal {
            PlannedMeal(slot: slot, recipeID: recipe.id, lunchOrderID: nil, name: recipe.name,
                        kcal: recipe.perPortion.kcal, protein: recipe.perPortion.protein,
                        isBoxNight: false, isOfficeLunch: false, time: nil)
        }
    }

    /// Days are first sought this close to their aim, inside the band.
    static let preferredKcalMargin = 75

    /// C3 (Advisor, 18 Nov): no formal split, but within the band training
    /// days (strength, run, basketball) take the extras first and rest days sit
    /// low. A training day aims up to this much above the week's target.
    public static let trainingDayExtraKcal = 75
    /// A rest day aims at most this much below it, so it stays well inside the band.
    public static let restDayMaxShortfallKcal = 100

    /// Each day's aim. Rest days give back what training days take, so the
    /// week averages the target: with 4 training and 3 rest days, +75 and −100;
    /// with 5 and 2, rest days are capped at −100 and training days get +40.
    /// No lean when the week is all one kind.
    static func dayAims(target: NutritionContent.DailyTarget, trainingDays: Set<Weekday>) -> [Weekday: Int] {
        let training = Weekday.allCases.filter(trainingDays.contains)
        let rest = Weekday.allCases.filter { !trainingDays.contains($0) }
        guard !training.isEmpty, !rest.isEmpty else {
            return Dictionary(uniqueKeysWithValues: Weekday.allCases.map { ($0, target.kcal) })
        }
        let down = min(restDayMaxShortfallKcal,
                       Int((Double(trainingDayExtraKcal * training.count) / Double(rest.count)).rounded()),
                       target.kcal - target.kcalMin)
        let up = Int((Double(down * rest.count) / Double(training.count)).rounded())
        return Dictionary(uniqueKeysWithValues:
            training.map { ($0, target.kcal + up) } + rest.map { ($0, target.kcal - down) })
    }

    /// C3: the week's average within this of the target (Advisor: ± 50).
    static let weeklyAverageMarginKcal = 40

    /// C3: nudges the week's average onto the target, one extra at a time,
    /// after each day was planned towards its aim (recipes come in steps of
    /// 150–700 kcal, so days land near, not on, their aims). Short: add an
    /// extra to a training day first, then a rest day. Over: take an extra off
    /// a rest day first, then a training day. Every day stays in the band with
    /// its protein; when nothing fits, the week stays as it is.
    static func balance(_ days: inout [(date: Date, weekday: Weekday, meals: [PlannedMeal], dinnerKind: String, rotation: Int)],
                        content: NutritionContent, target: NutritionContent.DailyTarget, trainingDays: Set<Weekday>) {
        func kcal(_ m: [PlannedMeal]) -> Int { m.reduce(0) { $0 + $1.kcal } }
        func protein(_ m: [PlannedMeal]) -> Int { m.reduce(0) { $0 + $1.protein } }
        let margin = weeklyAverageMarginKcal * days.count
        let goal = target.kcal * days.count
        let trainingFirst = days.indices.sorted { trainingDays.contains(days[$0].weekday) && !trainingDays.contains(days[$1].weekday) }
        for _ in 0..<(days.count * 2) {
            let total = days.reduce(0) { $0 + kcal($1.meals) }
            if total < goal - margin {
                // Add one extra where it fits best: the day furthest under the target, training days first.
                let order = trainingFirst.sorted {
                    let (a, b) = (trainingDays.contains(days[$0].weekday), trainingDays.contains(days[$1].weekday))
                    return a != b ? a : kcal(days[$0].meals) < kcal(days[$1].meals)
                }
                var changed = false
                for i in order {
                    let now = kcal(days[i].meals)
                    let next = withExtras(days[i].meals, content: content, target: target,
                                          aim: now + 1 + preferredKcalMargin, dinnerKind: days[i].dinnerKind,
                                          rotation: days[i].rotation)
                    if kcal(next) > now { days[i].meals = next; changed = true; break }
                }
                if !changed { return }
            } else if total > goal + margin {
                // Take one extra off where it fits: rest days first, the highest day first.
                let order = trainingFirst.reversed().sorted {
                    let (a, b) = (trainingDays.contains(days[$0].weekday), trainingDays.contains(days[$1].weekday))
                    return a != b ? !a : kcal(days[$0].meals) > kcal(days[$1].meals)
                }
                var changed = false
                search: for i in order {
                    for extra in days[i].meals.reversed() where extra.slot == .extra {
                        let next = days[i].meals.filter { $0 != extra }
                        if kcal(next) >= target.kcalMin, protein(next) >= target.proteinMin {
                            days[i].meals = next; changed = true; break search
                        }
                    }
                }
                if !changed { return }
            } else {
                break
            }
        }
        // Training days above rest days on average (Advisor: extras on training
        // days first): move an extra from the fullest rest day to the emptiest
        // training day while that keeps both days, and the week, in their limits.
        func average(_ training: Bool) -> Double {
            let picked = days.filter { trainingDays.contains($0.weekday) == training }
            return picked.isEmpty ? 0 : Double(picked.reduce(0) { $0 + kcal($1.meals) }) / Double(picked.count)
        }
        guard days.contains(where: { trainingDays.contains($0.weekday) }),
              days.contains(where: { !trainingDays.contains($0.weekday) }) else { return }
        for _ in 0..<days.count where average(true) <= average(false) {
            let rest = days.indices.filter { !trainingDays.contains(days[$0].weekday) }
                .sorted { kcal(days[$0].meals) > kcal(days[$1].meals) }
            let training = days.indices.filter { trainingDays.contains(days[$0].weekday) }
                .sorted { kcal(days[$0].meals) < kcal(days[$1].meals) }
            var moved = false
            search: for r in rest {
                for extra in days[r].meals.reversed() where extra.slot == .extra {
                    let lighter = days[r].meals.filter { $0 != extra }
                    guard kcal(lighter) >= target.kcalMin, protein(lighter) >= target.proteinMin else { continue }
                    for t in training {
                        let now = kcal(days[t].meals)
                        let heavier = withExtras(days[t].meals, content: content, target: target,
                                                 aim: now + 1 + preferredKcalMargin, dinnerKind: days[t].dinnerKind,
                                                 rotation: days[t].rotation)
                        let total = days.reduce(0) { $0 + kcal($1.meals) } - kcal(days[r].meals) + kcal(lighter)
                            - now + kcal(heavier)
                        guard kcal(heavier) > now, abs(total - goal) <= margin + 70 else { continue }
                        days[r].meals = lighter
                        days[t].meals = heavier
                        moved = true
                        break search
                    }
                }
            }
            if !moved { return }
        }
    }

    /// Closes a day still under the band (a raised weekly target, or
    /// maintenance) with the content's extras, by the Advisor's order: the
    /// protein boost first when planned protein is short, then each step of
    /// `extraRules.order` (one of "a|b|c", rotating by day) until the day is
    /// in the band. Never more than `maxPerDay` extras, nor two of a kind, nor
    /// one that overshoots the band. No extras, or none needed: unchanged.
    static func withExtras(_ meals: [PlannedMeal], content: NutritionContent, target: NutritionContent.DailyTarget,
                           aim: Int? = nil, dinnerKind: String, rotation: Int) -> [PlannedMeal] {
        // C3: fill towards the day's aim, not just into the band.
        let fillTo = aim.map { max(target.kcalMin, $0 - preferredKcalMargin) } ?? target.kcalMin
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

        guard totals(meals).kcal < fillTo || totals(meals).protein < target.proteinMin else { return meals }
        if totals(meals).protein < rules.proteinFirst.whenPlannedProteinBelow,
           let boost = content.recipe(rules.proteinFirst.extra), let next = adding(boost) {
            take(boost, next)
        }
        for step in rules.steps {
            guard totals(meals).kcal < fillTo else { break }
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
