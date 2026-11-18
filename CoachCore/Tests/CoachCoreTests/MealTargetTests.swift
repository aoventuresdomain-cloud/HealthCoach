import Foundation
import Testing
@testable import CoachCore

/// Board C3: meals follow the week's calorie target (Advisor ruling, 18 Nov).
@Suite struct MealTargetTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func at(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func library() throws -> ContentLibrary { try ContentLibrary.load(from: contentRoot) }

    /// Phase 1: Upper A Mon, run Tue, basketball Wed, full body Thu, Upper B Sat.
    static let training: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .saturday]

    private static let weeks: [(name: String, answers: WeekAnswers)] = [
        ("all home", WeekAnswers()),
        ("all office", WeekAnswers(officeDays: [.monday, .tuesday, .wednesday, .thursday, .friday])),
        ("hybrid", WeekAnswers(officeDays: [.monday, .tuesday, .thursday])),
    ]

    private func week(_ target: Int, _ answers: WeekAnswers, weekOffset: Int = 0,
                      training: Set<Weekday> = MealTargetTests.training) throws -> MealPlan {
        let lib = try library()
        let monday = try #require(calendar.date(byAdding: .day, value: 7 * weekOffset, to: at(2026, 11, 23)))
        return MealPlan.week(monday: monday, content: lib.nutrition, lunchOrders: lib.lunchOrders.orders,
                             answers: answers, programmeID: "phase-1", kcalTarget: target,
                             trainingDays: training, calendar: calendar)
    }

    @Test(arguments: [1850, 2000, 2200, 2450])
    func everyDayFollowsTheTarget(target: Int) throws {
        for (name, answers) in Self.weeks {
            for weekOffset in 0..<4 {
                let plan = try week(target, answers, weekOffset: weekOffset)
                #expect(plan.days.count == 7)
                for day in plan.days {
                    let where_ = "\(target) \(name) w\(weekOffset) \(day.weekday): \(day.kcal) kcal, \(day.protein) g"
                    #expect(abs(day.kcal - target) <= 150, "\(where_)")
                    #expect(day.kcal >= 1700, "\(where_)")
                    #expect(day.protein >= 150, "\(where_)")
                }
                let average = Double(plan.days.map(\.kcal).reduce(0, +)) / 7
                #expect(abs(average - Double(target)) <= 50, "\(target) \(name) w\(weekOffset): average \(average)")
            }
        }
    }

    @Test(arguments: [1850, 2000, 2200, 2450])
    func trainingDaysEatMoreThanRestDays(target: Int) throws {
        for (name, answers) in Self.weeks {
            let plan = try week(target, answers)
            let training = plan.days.filter { Self.training.contains($0.weekday) }
            let rest = plan.days.filter { !Self.training.contains($0.weekday) }
            let up = Double(training.map(\.kcal).reduce(0, +)) / Double(training.count)
            let down = Double(rest.map(\.kcal).reduce(0, +)) / Double(rest.count)
            #expect(up > down, "\(target) \(name): training \(up), rest \(down)")
            // The aims lean, but stay inside the band.
            for day in plan.days {
                let aim = try #require(day.aimKcal)
                #expect(Self.training.contains(day.weekday) ? aim > target : aim < target)
                #expect(abs(aim - target) <= 100)
            }
        }
    }

    @Test func thePlannersTrainingDaysAreSessionsAndBasketball() throws {
        let lib = try library()
        let programme = try #require(lib.programmes["phase-1"])
        var profile = Profile()
        profile.programme.startDate = at(2026, 11, 23)
        let week = WeekPlanner.plan(weekStarting: at(2026, 11, 23), programme: programme, profile: profile,
                                    answers: WeekAnswers(), calendar: calendar)
        // Week 1: no second run yet, and Sunday's walk doesn't count.
        #expect(week.trainingDays(programme: programme) == Self.training)
    }

    @Test func noLeanWithoutTrainingDays() throws {
        let plan = try week(2000, WeekAnswers(), training: [])
        #expect(plan.days.allSatisfy { $0.aimKcal == nil })
    }

    @Test(arguments: [1850, 2000, 2200, 2450])
    func boxNightsStayMondayToThursday(target: Int) throws {
        let plan = try week(target, WeekAnswers(officeDays: [.monday, .tuesday, .thursday]))
        let box = plan.days.filter { $0.meal(.dinner)?.isBoxNight == true }.map(\.weekday)
        #expect(box == [.monday, .tuesday, .wednesday, .thursday])
    }

    @Test func theTopUpListChangesWithTheTarget() throws {
        let content = try library().nutrition
        func list(_ target: Int) throws -> [String: String] {
            let items = ShoppingList.week(try week(target, WeekAnswers()), content: content)
            return Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.quantityText) })
        }
        let normal = try list(2000), maintenance = try list(2450), low = try list(1850)
        #expect(normal != maintenance)
        #expect(normal != low)
        // More food at maintenance: something new on the list, or more of something.
        #expect(maintenance.count > normal.count || maintenance.contains { normal[$0.key] != $0.value })
    }

    @Test func dayAimsBalanceToTheTarget() throws {
        let base = try #require(try library().nutrition.dailyTargets["phase-1"])
        for training in [Self.training, [.monday, .tuesday, .thursday, .saturday], [.monday]] as [Set<Weekday>] {
            for kcal in [1850, 2000, 2200, 2450] {
                let aims = MealPlan.dayAims(target: base.with(kcal: kcal), trainingDays: training)
                let total = aims.values.reduce(0, +)
                #expect(abs(total - 7 * kcal) <= 7, "\(kcal) \(training): \(aims)")
                #expect(aims.values.allSatisfy { $0 >= 1700 && abs($0 - kcal) <= 150 })
            }
        }
    }
}
