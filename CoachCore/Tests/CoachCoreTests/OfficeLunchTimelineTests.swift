import Foundation
import Testing
@testable import CoachCore

/// N9a (ease budget D8, A3): the office lunch order is a row on Today's
/// timeline on office days only, and it is the order Meals plans that day,
/// within the N4 walk answer and never a disliked one.
@Suite struct OfficeLunchTimelineTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func date(_ d: Int, hour: Int = 7) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
    }

    private func library() throws -> ContentLibrary { try ContentLibrary.load(from: contentRoot) }

    private func profile(walk: Int? = nil, dislikes: [String] = []) -> Profile {
        var p = Profile()
        p.confirmed = true
        p.programme.startDate = date(23, hour: 0)
        p.answerFoodQuestion {
            $0.officeLunchMaxWalkMinutes = walk
            $0.dislikes = dislikes
        }
        return p
    }

    /// Office Tuesday and Thursday in week 1 (Monday 23 Nov 2026).
    private let answers = WeekAnswers(officeDays: [.tuesday, .thursday],
                                      earlyStarts: [.tuesday: TimeOfDay(hour: 8, minute: 0)])

    /// Today as the app builds it: the planner's day plus the meal plan's lunch, the same way Meals plans it.
    private func today(_ day: Int, profile: Profile, answers: WeekAnswers? = nil) throws
        -> (plan: DayPlan, meals: MealDay?, orders: [LunchOrder]) {
        let lib = try library()
        let answers = answers ?? self.answers
        let programme = try #require(lib.programmes["phase-1"])
        let base = try #require(DayPlan.make(for: date(day), programme: programme, profile: profile,
                                             answers: { _ in answers }, calendar: calendar))
        let orders = profile.food.lunchOrders(lib.lunchOrders)
        let week = MealPlan.week(monday: date(23, hour: 0), content: lib.nutrition, lunchOrders: orders,
                                 answers: answers, programmeID: "phase-1",
                                 dislikes: { profile.dislikes(on: $0, calendar: calendar) }, calendar: calendar)
        let meals = week.day(date(day), calendar: calendar)
        return (base.withOfficeLunch(meals, orders: orders), meals, orders)
    }

    @Test func anOfficeDayHasTheLunchRowAtHalfTwelveInTimeOrder() throws {
        let tuesday = try today(24, profile: profile())
        #expect(tuesday.plan.timeline.map(\.kind) == [.wake, .session, .leave, .lunch, .windDown])
        let row = try #require(tuesday.plan.timeline.first { $0.kind == .lunch })
        #expect(row.time == TimeOfDay(hour: 12, minute: 30))
        #expect(row.title == "Lunch")
        #expect(row.id == "lunch")
        // The order Meals plans for that day, named as "<order>, <place>".
        let order = try #require(OfficeLunch.planned(tuesday.meals, orders: tuesday.orders))
        #expect(row.detail == "\(order.order), \(order.place)")
        #expect(tuesday.meals?.meal(.lunch)?.lunchOrderID == order.id)
    }

    @Test func homeDaysAndWeekendsHaveNoLunchRow() throws {
        let p = profile()
        for day in [23, 25, 27, 28, 29] {  // Mon, Wed, Fri home; Sat, Sun
            let home = try today(day, profile: p)
            #expect(!home.plan.timeline.contains { $0.kind == .lunch }, "day \(day)")
            #expect(OfficeLunch.planned(home.meals, orders: home.orders) == nil, "day \(day)")
        }
        // A Saturday marked as office still has no office lunch (the meal plan's rule).
        let saturday = try today(28, profile: p, answers: WeekAnswers(officeDays: [.saturday]))
        #expect(!saturday.plan.timeline.contains { $0.kind == .lunch })
    }

    @Test func aWeekWithNoOfficeDaysIsUnchanged() throws {
        let lib = try library()
        let programme = try #require(lib.programmes["phase-1"])
        let p = profile()
        for day in 23...29 {
            let base = try #require(DayPlan.make(for: date(day), programme: programme, profile: p, calendar: calendar))
            let none = try today(day, profile: p, answers: WeekAnswers())
            #expect(none.plan == base, "day \(day)")
        }
    }

    @Test func theRowFollowsTheN4WalkAnswer() throws {
        // 5 min: only orders within 5 min are ever on the row.
        let p = profile(walk: 5)
        for day in [24, 26] {
            let office = try today(day, profile: p)
            let order = try #require(OfficeLunch.planned(office.meals, orders: office.orders))
            #expect(order.walkMinutes <= 5)
            #expect(office.plan.timeline.contains { $0.kind == .lunch })
        }
        // Unanswered: the content's limit applies.
        let lib = try library()
        let unanswered = try today(24, profile: profile())
        let order = try #require(OfficeLunch.planned(unanswered.meals, orders: unanswered.orders))
        #expect(order.walkMinutes <= lib.lunchOrders.origin.maxWalkMinutes)
        #expect(unanswered.orders.count == lib.lunchOrders.orders.count)
    }

    @Test func theRowNeverNamesADislikedOrder() throws {
        let first = try today(24, profile: profile())
        let usual = try #require(OfficeLunch.planned(first.meals, orders: first.orders))
        // Dislike the usual order: the row names another, never one the dislike matches.
        let disliked = try today(24, profile: profile(dislikes: [usual.order]))
        let other = try #require(OfficeLunch.planned(disliked.meals, orders: disliked.orders))
        #expect(other.id != usual.id)
        #expect(!other.isDisliked(by: [usual.order]))
        let row = try #require(disliked.plan.timeline.first { $0.kind == .lunch })
        #expect(row.detail == "\(other.order), \(other.place)")
        // Every order disliked (all contain chicken): a home lunch, so no office row.
        let none = try today(24, profile: profile(dislikes: ["chicken"]))
        #expect(!none.plan.timeline.contains { $0.kind == .lunch })
        #expect(none.meals?.meal(.lunch)?.isOfficeLunch == false)
    }

    @Test func theCurrentRowMovesPastLunchAtHalfTwelve() throws {
        let tuesday = try today(24, profile: profile()).plan
        let lunch = try #require(tuesday.timeline.firstIndex { $0.kind == .lunch })
        #expect(tuesday.timelineProgress(at: TimeOfDay(hour: 12, minute: 0)) == lunch)
        #expect(tuesday.timelineProgress(at: TimeOfDay(hour: 13, minute: 0)) == lunch + 1)
    }

    @Test func addingTheRowTwiceKeepsOne() throws {
        let tuesday = try today(24, profile: profile())
        let again = tuesday.plan.withOfficeLunch(tuesday.meals, orders: tuesday.orders)
        #expect(again.timeline.filter { $0.kind == .lunch }.count == 1)
    }

    @Test func anUntimedEventStaysAfterLunch() throws {
        let tuesday = try today(24, profile: profile())
        let event = DayPlan.TimelineItem(kind: .fixed, time: nil, title: "Basketball", detail: "Evening")
        var rows = tuesday.plan.timeline
        rows.removeAll { $0.kind == .lunch }
        rows.insert(event, at: rows.count - 1)
        let base = DayPlan(planned: tuesday.plan.planned, alarm: tuesday.plan.alarm, session: tuesday.plan.session,
                           leave: tuesday.plan.leave, windDown: tuesday.plan.windDown,
                           lightsOut: tuesday.plan.lightsOut, timeline: rows)
        let withLunch = base.withOfficeLunch(tuesday.meals, orders: tuesday.orders)
        #expect(withLunch.timeline.map(\.kind) == [.wake, .session, .leave, .lunch, .fixed, .windDown])
    }

    @Test func anotherStartsAtThePlannedOrderAndWraps() throws {
        let tuesday = try today(24, profile: profile())
        let orders = tuesday.orders
        let planned = try #require(OfficeLunch.planned(tuesday.meals, orders: orders))
        #expect(OfficeLunch.suggestion(tuesday.meals, orders: orders) == planned)
        let start = try #require(orders.firstIndex(of: planned))
        #expect(OfficeLunch.suggestion(tuesday.meals, orders: orders, step: 1) == orders[(start + 1) % orders.count])
        #expect(OfficeLunch.suggestion(tuesday.meals, orders: orders, step: orders.count) == planned)
        let monday = try today(23, profile: profile())
        #expect(OfficeLunch.suggestion(monday.meals, orders: monday.orders, step: 1) == nil)
    }
}
