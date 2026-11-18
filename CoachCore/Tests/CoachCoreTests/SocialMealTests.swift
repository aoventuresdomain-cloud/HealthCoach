import Foundation
import Testing
@testable import CoachCore

/// Board C4: social meals (Advisor ruling, 18 Nov).
@Suite struct SocialMealTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: d))! }

    private func week(_ target: Int = 2000, answers: WeekAnswers = WeekAnswers()) throws -> MealPlan {
        let lib = try ContentLibrary.load(from: contentRoot)
        return MealPlan.week(monday: day(23), content: lib.nutrition, lunchOrders: lib.lunchOrders.orders,
                             answers: answers, programmeID: "phase-1", kcalTarget: target,
                             trainingDays: MealTargetTests.training, calendar: calendar)
    }

    private func trims(_ d: MealDay) -> Int { d.meals.filter { $0.name == SocialMeals.trimName }.map(\.kcal).reduce(0, +) }

    @Test func fridaysSocialMealReplacesItsDinner() throws {
        let plan = try week()
        let social = plan.withSocialMeals([day(27)], calendar: calendar)
        let friday = try #require(social.day(day(27), calendar: calendar))
        #expect(friday.isSocial)
        #expect(friday.meal(.dinner)?.name == "Social meal")
        #expect(friday.meal(.dinner)?.kcal == 1000)
        #expect(friday.meals.filter { $0.slot == .dinner }.count == 1)
        // No saving up on the day itself: its other meals are as planned, about 40 g protein each.
        let planned = try #require(plan.day(day(27), calendar: calendar))
        #expect(friday.meals.filter { $0.slot != .dinner } == planned.meals.filter { $0.slot != .dinner })
        #expect(friday.meals.filter { $0.slot == .breakfast || $0.slot == .lunch }.allSatisfy { $0.protein >= 35 })
        #expect(trims(friday) == 0)
    }

    @Test(arguments: [1850, 2000, 2200, 2450])
    func theExcessComesOffOtherDaysAtMost100(target: Int) throws {
        let plan = try week(target)
        let social = plan.withSocialMeals([day(27)], calendar: calendar)
        let replaced = try #require(plan.day(day(27), calendar: calendar)?.meal(.dinner)?.kcal)
        let excess = 1000 - replaced
        var trimmed = 0
        for (before, after) in zip(plan.days, social.days) where !after.isSocial {
            let trim = -trims(after)
            #expect((0...100).contains(trim), "\(after.weekday): \(trim)")
            #expect(after.kcal >= 1700, "\(after.weekday): \(after.kcal)")
            #expect(after.protein == before.protein, "never from protein")
            trimmed += trim
        }
        // Spread across the week up to its limits; the rest is absorbed, never more.
        #expect(trimmed <= excess)
        #expect(trimmed == min(excess, social.days.filter { !$0.isSocial }.map { min(100, before(plan, $0) - 1700) }.reduce(0, +)))
    }

    private func before(_ plan: MealPlan, _ d: MealDay) -> Int { plan.day(d.date, calendar: calendar)!.kcal }

    /// QA (C4 floor squeeze): two social meals in a 1,850 week, every other day still at or above 1,700.
    @Test func twoSocialMealsInAn1850WeekKeepTheFloor() throws {
        for answers in [WeekAnswers(), WeekAnswers(officeDays: [.monday, .tuesday, .thursday])] {
            let social = try week(1850, answers: answers).withSocialMeals([day(27), day(28)], calendar: calendar)
            #expect(social.days.filter(\.isSocial).map(\.weekday) == [.friday, .saturday])
            for d in social.days where !d.isSocial {
                #expect(d.kcal >= 1700, "\(d.weekday): \(d.kcal)")
                #expect(d.protein >= 150, "\(d.weekday): \(d.protein) g")
                #expect(-trims(d) <= 100)
            }
        }
    }

    @Test func theCounterIsTwoAWeekAndAThirdIsFlagged() {
        let monday = day(23)
        #expect(SocialMeals.count([], weekOf: monday, calendar: calendar).text == "0 of 2")
        let one = SocialMeals.count([day(27)], weekOf: monday, calendar: calendar)
        #expect(one.text == "1 of 2" && !one.flagged)
        #expect(!SocialMeals.count([day(27), day(28)], weekOf: monday, calendar: calendar).flagged)
        let three = SocialMeals.count([day(26), day(27), day(28)], weekOf: monday, calendar: calendar)
        #expect(three.used == 3 && three.flagged)
        // Last week's and next week's don't count; two on one day count once.
        #expect(SocialMeals.count([day(22), day(30), day(27), day(27)], weekOf: monday, calendar: calendar).used == 1)
    }

    @Test func aThirdIsAllowedAndPlanned() throws {
        let social = try week().withSocialMeals([day(26), day(27), day(28)], calendar: calendar)
        #expect(social.days.filter(\.isSocial).count == 3)
        for d in social.days where !d.isSocial { #expect(d.kcal >= 1700) }
    }

    @Test func nothingCarriesIntoNextWeek() throws {
        let lib = try ContentLibrary.load(from: contentRoot)
        let next = MealPlan.week(monday: day(30), content: lib.nutrition, lunchOrders: lib.lunchOrders.orders,
                                 answers: WeekAnswers(), programmeID: "phase-1", kcalTarget: 2000,
                                 trainingDays: MealTargetTests.training, calendar: calendar)
        // Social meals last week leave next week's plan as it is.
        #expect(next.withSocialMeals([day(27), day(28)], calendar: calendar) == next)
    }

    @Test func theTopUpListDropsTheReplacedDinner() throws {
        let content = try ContentLibrary.load(from: contentRoot).nutrition
        let plan = try week()
        let friday = try #require(plan.day(day(27), calendar: calendar)?.meal(.dinner)?.recipeID)
        let social = plan.withSocialMeals([day(27)], calendar: calendar)
        #expect(ShoppingList.week(social, content: content) != ShoppingList.week(plan, content: content))
        #expect(!social.days.contains { $0.meals.contains { $0.recipeID == friday } } || plan.days.filter { $0.meal(.dinner)?.recipeID == friday }.count > 1)
    }

    @Test func theSummaryFlagsAThird() throws {
        let lib = try ContentLibrary.load(from: contentRoot)
        let programme = try #require(lib.programmes["phase-1"])
        var profile = Profile()
        profile.confirmed = true
        profile.programme.startDate = day(16)
        func text(_ meals: [Date]) throws -> String {
            try #require(CoachSummary.text(programme: programme, profile: profile, history: [], weights: [], blocks: [],
                                           socialMeals: meals, now: day(29), calendar: calendar))
        }
        #expect(!(try text([])).contains("Social meals"))
        #expect(try text([day(27)]).contains("Social meals this week: 1 of 2, counted as 1,000 kcal each, untracked"))
        #expect(try text([day(26), day(27), day(28)]).contains("3 of 2 (over the allowance, flagged)"))
    }
}
