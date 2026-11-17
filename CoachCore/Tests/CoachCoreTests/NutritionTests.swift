import Foundation
import Testing
@testable import CoachCore

/// Board M3-02 (meal plan) and M3-03 (top-up list), on the M3-01 content.
@Suite struct NutritionTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func at(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func library() throws -> ContentLibrary { try ContentLibrary.load(from: contentRoot) }

    private static let weeks: [(name: String, answers: WeekAnswers)] = [
        ("all home", WeekAnswers()),
        ("all office", WeekAnswers(officeDays: [.monday, .tuesday, .wednesday, .thursday, .friday])),
        ("hybrid", WeekAnswers(officeDays: [.monday, .tuesday, .thursday])),
    ]

    private func plan(_ answers: WeekAnswers, monday: Date? = nil) throws -> MealPlan {
        let lib = try library()
        return MealPlan.week(monday: monday ?? at(2026, 11, 23), content: lib.nutrition,
                             lunchOrders: lib.lunchOrders.orders, answers: answers,
                             programmeID: "phase-1", calendar: calendar)
    }

    // MARK: Content

    @Test func contentIsSchemaVersion1AndValid() throws {
        let lib = try library()
        #expect(lib.nutrition.schemaVersion == 1)
        #expect(lib.nutrition.problems().isEmpty)
        #expect(lib.lunchOrders.schemaVersion == 1)
        #expect(lib.lunchOrders.problems().isEmpty)
        #expect((5...6).contains(lib.lunchOrders.orders.count))
    }

    @Test func aBrokenRecipeIsNamed() throws {
        let url = contentRoot.appendingPathComponent(ContentLibrary.recipesPath)
        var json = try String(contentsOf: url, encoding: .utf8)
        json = json.replacingOccurrences(of: "\"ingredient\": \"granola\"", with: "\"ingredient\": \"gravel\"")
        let broken = try NutritionContent.decode(Data(json.utf8), file: "recipes.json")
        #expect(broken.problems().contains("recipe yogurt-bowl: unknown ingredient gravel"))
    }

    @Test func aNewerRecipeFileIsRejectedPlainly() {
        let data = Data(#"{"schemaVersion": 2}"#.utf8)
        #expect(throws: ContentError.newerThanSupported(file: "recipes.json", found: 2, supported: 1)) {
            try NutritionContent.decode(data, file: "recipes.json")
        }
    }

    // MARK: Meal plan (M3-02)

    @Test func everyDayIsInsideTheBandForEveryKindOfWeek() throws {
        for (name, answers) in Self.weeks {
            for weekOffset in 0..<6 {
                let monday = try #require(calendar.date(byAdding: .day, value: 7 * weekOffset, to: at(2026, 11, 23)))
                let week = try plan(answers, monday: monday)
                #expect(week.days.count == 7, "\(name)")
                for day in week.days {
                    #expect(day.withinBand, "\(name) week \(weekOffset + 1) \(day.weekday): \(day.kcal) kcal, \(day.protein) g")
                    #expect(day.meals.map(\.slot) == [.breakfast, .lunch, .dinner, .snack], "\(name) \(day.weekday)")
                    #expect(day.meals.allSatisfy { $0.ticked })
                }
                // About 160 g protein and the phase's calories, across the week.
                let protein = Double(week.days.map(\.protein).reduce(0, +)) / 7
                let kcal = Double(week.days.map(\.kcal).reduce(0, +)) / 7
                #expect((150...175).contains(protein), "\(name): \(protein) g a day")
                #expect(abs(kcal - 2000) <= 100, "\(name): \(kcal) kcal a day")
            }
        }
    }

    @Test func theBandFollowsTheWeeksTarget() throws {
        let lib = try library()
        let base = try #require(lib.nutrition.dailyTargets["phase-1"])
        #expect(base.kcal == 2000 && base.kcalMin == 1850 && base.kcalMax == 2150)
        // Never under 1,700, whatever the target.
        #expect(base.with(kcal: 1800).kcalMin == 1700)
        let week = MealPlan.week(monday: at(2026, 11, 23), content: lib.nutrition, lunchOrders: lib.lunchOrders.orders,
                                 answers: WeekAnswers(), programmeID: "phase-1", kcalTarget: 1950, calendar: calendar)
        for day in week.days {
            #expect(day.target.kcal == 1950)
            #expect(day.withinBand, "\(day.weekday): \(day.kcal) kcal, \(day.protein) g")
        }
    }

    @Test func extrasCloseDaysUnderARaisedTarget() throws {
        let lib = try library()
        for target in [2200, 2450] {
            for (name, answers) in Self.weeks {
                let week = MealPlan.week(monday: at(2026, 11, 23), content: lib.nutrition, lunchOrders: lib.lunchOrders.orders,
                                         answers: answers, programmeID: "phase-1", kcalTarget: target, calendar: calendar)
                for day in week.days {
                    #expect(day.withinBand, "\(target) \(name) \(day.weekday): \(day.kcal) kcal, \(day.protein) g")
                    let extras = day.meals.filter { lib.nutrition.recipe($0.recipeID ?? "")?.kind == .extra }
                    #expect(extras.count <= 2, "\(day.weekday): \(extras.map(\.name))")
                    let kinds = extras.compactMap { lib.nutrition.recipe($0.recipeID ?? "")?.extraKind }
                    #expect(Set(kinds).count == kinds.count, "one of each kind")
                    #expect(day.meals.filter { $0.slot == .breakfast }.count == 1)
                }
            }
        }
        // At the normal target nothing is added.
        let normal = try plan(WeekAnswers())
        #expect(normal.days.allSatisfy { $0.meal(.extra) == nil })
    }

    @Test func extrasFollowTheAdvisorsOrder() throws {
        let content = try library().nutrition
        let base = try #require(content.dailyTargets["phase-1"])
        func meal(_ slot: MealSlot, _ kcal: Int, _ protein: Int) -> PlannedMeal {
            PlannedMeal(slot: slot, recipeID: nil, lunchOrderID: nil, name: "\(slot)", kcal: kcal, protein: protein,
                        isBoxNight: false, isOfficeLunch: false, time: nil)
        }
        // Protein short (140 g): the chicken boost goes in first, then a side.
        let short = [meal(.breakfast, 500, 40), meal(.lunch, 500, 40), meal(.dinner, 650, 40), meal(.snack, 220, 20)]
        let filled = MealPlan.withExtras(short, content: content, target: base.with(kcal: 2300),
                                         dinnerKind: "box-night", rotation: 0)
        #expect(filled.compactMap(\.recipeID) == ["dinner-chicken-boost", "side-rice"])
        // Protein fine: a side first, then the yogurt bowl; never past 2 extras.
        let fine = [meal(.breakfast, 500, 45), meal(.lunch, 500, 50), meal(.dinner, 650, 40), meal(.snack, 220, 21)]
        let up = MealPlan.withExtras(fine, content: content, target: base.with(kcal: 2450), dinnerKind: "dinner", rotation: 1)
        #expect(up.compactMap(\.recipeID) == ["side-potatoes", "second-snack-yogurt"])
        // Nothing needed: unchanged.
        #expect(MealPlan.withExtras(fine, content: content, target: base.with(kcal: 1950), dinnerKind: "dinner", rotation: 0) == fine)
    }

    @Test func theBandMatchesTheRulesEngine() throws {
        let base = try #require(try library().nutrition.dailyTargets["phase-1"])
        #expect(base.kcal == CalorieRules.startKcal)
        for kcal in [1850, 2000, 2200, 2450] {
            let ours = base.with(kcal: kcal)
            let engine = max(CalorieRules.dayFloorKcal, kcal - CalorieRules.dayBandKcal)...(kcal + CalorieRules.dayBandKcal)
            #expect(ours.kcalMin...ours.kcalMax == engine, "\(kcal)")
        }
    }

    @Test func boxNightsSundayCookAndHomeDinners() throws {
        let week = try plan(WeekAnswers())
        for weekday in [Weekday.monday, .tuesday, .wednesday, .thursday] {
            let dinner = try #require(week.days.first { $0.weekday == weekday }?.meal(.dinner))
            #expect(dinner.isBoxNight)
            #expect(dinner.kcal == 650 && dinner.protein == 40)
            #expect(dinner.recipeID == nil)
        }
        let sunday = try #require(week.days.last?.meal(.dinner))
        #expect(sunday.recipeID == "sunday-traybake")
        let friday = try #require(week.days[4].meal(.dinner)), saturday = try #require(week.days[5].meal(.dinner))
        #expect(!friday.isBoxNight && !saturday.isBoxNight)
        #expect(friday.recipeID != saturday.recipeID)
    }

    @Test func officeDaysGetALunchOrderAndHomeDaysAHomeLunch() throws {
        let lib = try library()
        let week = try plan(WeekAnswers(officeDays: [.monday, .tuesday, .thursday]))
        for day in week.days {
            let lunch = try #require(day.meal(.lunch))
            let office = [Weekday.monday, .tuesday, .thursday].contains(day.weekday)
            #expect(lunch.isOfficeLunch == office, "\(day.weekday)")
            if office {
                let order = try #require(lib.lunchOrders.orders.first { $0.id == lunch.lunchOrderID })
                #expect(lunch.kcal == order.kcal && lunch.protein == order.protein)
            } else {
                #expect(lib.nutrition.recipe(lunch.recipeID ?? "")?.kind == .lunch)
            }
        }
        // Not the same order three times.
        let orders = week.days.compactMap { $0.meal(.lunch)?.lunchOrderID }
        #expect(Set(orders).count == orders.count)
    }

    @Test func theShakeReplacesTheYogurtPotOnlyWhenProteinIsShort() throws {
        let content = try library().nutrition
        func meal(_ protein: Int) -> PlannedMeal {
            PlannedMeal(slot: .lunch, recipeID: nil, lunchOrderID: nil, name: "x", kcal: 500, protein: protein,
                        isBoxNight: false, isOfficeLunch: false, time: nil)
        }
        // 128 + 21 (pot) = 149 < 150: the shake.
        #expect(MealPlan.withSnack([meal(128)], weekday: .monday, content: content).last?.recipeID == "protein-shake")
        // 129 + 21 = 150: the pot.
        #expect(MealPlan.withSnack([meal(129)], weekday: .monday, content: content).last?.recipeID == "yogurt-pot")
    }

    @Test func wednesdaysSnackIsBeforeBasketball() throws {
        let week = try plan(WeekAnswers())
        #expect(week.days[2].meal(.snack)?.time == TimeOfDay(hour: 17, minute: 30))
        #expect(week.days[1].meal(.snack)?.time == nil)
    }

    @Test func supplementsFollowTheMonths() throws {
        let content = try library().nutrition
        #expect(MealPlan.supplementLine(content, month: 11) == "Creatine 5 g, Vitamin D 10 µg")
        #expect(MealPlan.supplementLine(content, month: 7) == "Creatine 5 g")
        #expect(try plan(WeekAnswers()).days[0].supplements == ["Creatine 5 g, Vitamin D 10 µg"])
    }

    @Test func theSameWeekPlansTheSameMealsAndTheNextWeekVaries() throws {
        let a = try plan(WeekAnswers()), b = try plan(WeekAnswers())
        #expect(a == b)
        let next = try plan(WeekAnswers(), monday: at(2026, 11, 30))
        #expect(a.days.map { $0.meal(.breakfast)?.recipeID } != next.days.map { $0.meal(.breakfast)?.recipeID })
    }

    @Test func recipeDetailHasIngredientsAndMethod() throws {
        let content = try library().nutrition
        let recipe = try #require(content.recipe("yogurt-bowl"))
        #expect(content.ingredientLines(recipe).first == "600 g 0% fat Greek yogurt")
        #expect(!recipe.method.isEmpty)
        #expect(NutritionContent.quantity(1250, unit: .g) == "1.3 kg")
        #expect(NutritionContent.quantity(1000, unit: .ml) == "1 l")
        #expect(NutritionContent.quantity(2.5, unit: .each) == "3")
    }

    // MARK: Top-up list (M3-03)

    @Test func oneMergedListInAisleOrder() throws {
        let content = try library().nutrition
        let week = try plan(WeekAnswers(officeDays: [.monday, .tuesday, .thursday]))
        let list = ShoppingList.week(week, content: content)
        #expect(!list.isEmpty)
        #expect(Set(list.map(\.id)).count == list.count, "one line per item")
        let ranks = list.map { content.aisleOrder.firstIndex(of: $0.aisle)! }
        #expect(ranks == ranks.sorted())

        // Merged: the yogurt across every recipe that uses it this week.
        var yogurt = 0.0
        for meal in week.days.flatMap(\.meals) {
            guard let recipe = content.recipe(meal.recipeID ?? "") else { continue }
            yogurt += recipe.ingredients.filter { $0.ingredient == "greek-yogurt-0" }.map(\.qty).reduce(0, +)
        }
        #expect(list.first { $0.id == "greek-yogurt-0" }?.quantityText == NutritionContent.quantity(yogurt, unit: .g))
    }

    @Test func boxNightsAndOfficeLunchesAddNothing() throws {
        let content = try library().nutrition
        let boxOnly = MealPlan(days: try plan(WeekAnswers()).days.map { day in
            MealDay(date: day.date, weekday: day.weekday, meals: day.meals.filter { $0.isBoxNight || $0.isOfficeLunch },
                    target: day.target, supplements: [])
        })
        // Only the supplements remain (staples).
        let list = ShoppingList.week(boxOnly, content: content)
        #expect(Set(list.map(\.id)) == ["creatine", "vitamin-d"])
        #expect(list.allSatisfy { $0.isStaple })
    }

    @Test func staplesAreTickedOnceAndOthersNever() throws {
        let content = try library().nutrition
        let list = ShoppingList.week(try plan(WeekAnswers()), content: content,
                                     tickedStaples: ["olive-oil", "greek-yogurt-0"])
        #expect(list.first { $0.id == "olive-oil" }?.ticked == true)
        #expect(list.first { $0.id == "greek-yogurt-0" }?.ticked == false) // not a staple
        #expect(list.filter(\.ticked).count == 1)
    }

    @Test func everyItemHasASearchLinkToTheDefaultShop() throws {
        let content = try library().nutrition
        let list = ShoppingList.week(try plan(WeekAnswers()), content: content)
        for item in list {
            let url = try #require(item.searchURL, "\(item.id)")
            #expect(url.absoluteString.hasPrefix("https://www.waitrose.com/ecom/shop/search?searchTerm="), "\(url)")
        }
        let yogurt = try #require(list.first { $0.id == "greek-yogurt-0" }?.searchURL)
        #expect(yogurt.absoluteString.hasSuffix("searchTerm=0%25%20fat%20greek%20yogurt%201kg"))
    }
}
