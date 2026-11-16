import Foundation
import Testing
@testable import CoachCore

/// Board M2-01: sessions placed around office days and basketball, never on
/// Wednesday; wake = first commitment − commute − shower − session − buffer,
/// protecting 7.5 h of sleep.
@Suite struct WeekPlannerTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    /// Week 1 starts Monday 23 Nov 2026.
    private func profile(_ edit: (inout Profile) -> Void = { _ in }) -> Profile {
        var p = Profile()
        p.confirmed = true
        p.programme.startDate = date(2026, 11, 23)
        edit(&p)
        return p
    }

    private func plan(week: Int = 1, _ answers: WeekAnswers, profile: Profile? = nil,
                      dropping: Set<String> = []) throws -> WeekPlan {
        let monday = calendar.date(byAdding: .day, value: 7 * (week - 1), to: date(2026, 11, 23))!
        return WeekPlanner.plan(weekStarting: monday, programme: try phase1(), profile: profile ?? self.profile(),
                                answers: answers, dropping: dropping, calendar: calendar)
    }

    private func t(_ h: Int, _ m: Int) -> TimeOfDay { TimeOfDay(hour: h, minute: m) }

    // MARK: The wake formula

    @Test func officeMorningWakeFollowsTheFormula() throws {
        // 09:00 − 25 commute − 15 shower − 39 min Upper A (week 1) = 07:41, rounded down
        // to 07:40; wake = 07:40 − 15 min buffer.
        let monday = try #require(try plan(WeekAnswers(officeDays: [.monday])).day(.monday))
        let session = try #require(monday.session)
        #expect(monday.kind == .office)
        #expect(session.sessionID == "upper-a")
        #expect(session.slot == .morning)
        #expect(session.start == t(7, 40))
        #expect(session.end == t(8, 19))
        #expect(monday.wake == t(7, 25))
        #expect(monday.leave == t(8, 35))
    }

    @Test func homeDaySkipsTheCommute() throws {
        let monday = try #require(try plan(WeekAnswers()).day(.monday))
        #expect(monday.kind == .home)
        #expect(monday.session?.start == t(8, 5))
        #expect(monday.wake == t(7, 50))
        #expect(monday.leave == nil)
    }

    @Test func lightsOutProtectsSevenAndAHalfHoursOfSleep() throws {
        // 08:00 start in the office: session 06:40, alarm 06:25, lights out 22:40 (7.5 h + 15 min).
        let monday = try #require(try plan(WeekAnswers(officeDays: [.monday], earlyStarts: [.monday: t(8, 0)])).day(.monday))
        #expect(monday.wake == t(6, 25))
        #expect(monday.lightsOutBefore == t(22, 40))
    }

    @Test func lightsOutNeverLaterThanTheLatestBedtime() throws {
        let monday = try #require(try plan(WeekAnswers()).day(.monday))
        // 07:50 alarm would allow 00:05; the latest bedtime (23:30) wins.
        #expect(monday.lightsOutBefore == t(23, 30))
    }

    @Test func tooEarlyForTheMorningMovesToTheEvening() throws {
        // 07:00 start: the alarm would be 05:25, before the 05:45 earliest wake.
        let monday = try #require(try plan(WeekAnswers(officeDays: [.monday], earlyStarts: [.monday: t(7, 0)])).day(.monday))
        let session = try #require(monday.session)
        #expect(session.slot == .evening)
        #expect(session.start == t(18, 25)) // 18:00 finish + 25 commute
        #expect(monday.wake == t(6, 5))     // still up for the 07:00 start
        #expect(monday.wake! >= Profile().schedule.earliestWake)
    }

    @Test func eveningOnlyWindowPlacesAfterWork() throws {
        let p = profile { $0.schedule.trainingWindows = .evening }
        let monday = try #require(try plan(WeekAnswers(), profile: p).day(.monday))
        #expect(monday.session?.slot == .evening)
        #expect(monday.session?.start == t(18, 0))
    }

    @Test func noRoomEitherSideMovesToTheNearestFreeDay() throws {
        let answers = WeekAnswers(officeDays: [.monday], earlyStarts: [.monday: t(7, 0)],
                                  lateFinishes: [.monday: t(20, 0)])
        let week = try plan(answers)
        #expect(week.day(.monday)?.session == nil)
        let friday = try #require(week.day(.friday)?.session)
        #expect(friday.sessionID == "upper-a")
        #expect(friday.movedFrom == .monday)
        #expect(week.unplaced.isEmpty)
    }

    @Test func noLegalDayLeavesItUnplacedRatherThanOnWednesday() throws {
        // Thursday and Friday both blocked: full body has nowhere legal to go
        // (Wednesday is basketball only; every other day has its own session).
        let answers = WeekAnswers(earlyStarts: [.thursday: t(6, 0), .friday: t(6, 0)],
                                  lateFinishes: [.thursday: t(20, 15), .friday: t(20, 15)])
        let week = try plan(answers)
        #expect(week.day(.wednesday)?.session == nil)
        #expect(week.day(.tuesday)?.session?.sessionID == "run-1")
        #expect(week.unplaced == [WeekPlan.Unplaced(sessionID: "full-body", scheduledOn: .thursday)])
    }

    @Test func theDayBeforeBasketballTakesUpperButNotFullBody() throws {
        // With the run left out, Tuesday is free. Upper A may move there; full body may not
        // (programme rule: nothing hard on legs the day before basketball).
        let blockedMonday = WeekAnswers(earlyStarts: [.monday: t(6, 0)], lateFinishes: [.monday: t(20, 15)])
        let upper = try plan(blockedMonday, dropping: ["run-1"])
        #expect(upper.day(.tuesday)?.session?.sessionID == "upper-a")
        #expect(upper.day(.tuesday)?.session?.movedFrom == .monday)

        let blockedThuFri = WeekAnswers(earlyStarts: [.thursday: t(6, 0), .friday: t(6, 0)],
                                        lateFinishes: [.thursday: t(20, 15), .friday: t(20, 15)])
        let full = try plan(blockedThuFri, dropping: ["run-1"])
        #expect(full.day(.tuesday)?.session == nil)
        #expect(full.unplaced.map(\.sessionID) == ["full-body"])
    }

    // MARK: Six office-day patterns

    static let patterns: [Set<Weekday>] = [
        [],
        [.monday, .tuesday, .wednesday, .thursday, .friday],
        [.monday, .tuesday, .thursday],
        [.tuesday, .thursday],
        [.monday, .wednesday, .friday],
        [.friday],
        [.wednesday, .thursday],
    ]

    @Test(arguments: WeekPlannerTests.patterns)
    func officePatternsPlaceEverySessionOnItsDay(_ office: Set<Weekday>) throws {
        let s = Profile().schedule
        for week in [1, 4] {
            let plan = try plan(week: week, WeekAnswers(officeDays: office))
            #expect(plan.unplaced.isEmpty)
            #expect(plan.day(.wednesday)?.session == nil)
            #expect(plan.day(.wednesday)?.fixed?.id == "basketball")
            for day in plan.days {
                #expect(day.kind == (day.weekday >= .saturday ? .dayOff : office.contains(day.weekday) ? .office : .home))
                guard let session = day.session else { continue }
                #expect(session.movedFrom == nil)
                if session.slot == .morning, day.kind != .dayOff {
                    let travel = day.kind == .office ? s.commuteMinutes : 0
                    #expect(session.end.minutesSinceMidnight + s.showerMinutes + travel <= s.workStart.minutesSinceMidnight)
                }
                if let wake = day.wake { #expect(wake >= s.earliestWake) }
                #expect(day.lightsOutBefore != nil || day.kind == .dayOff)
            }
            #expect(plan.days.compactMap(\.session).count == 5)
        }
    }

    // MARK: Days off, reduced week, clock change

    @Test func weekendSessionsStartAtNineWithNoCommute() throws {
        let week = try plan(WeekAnswers())
        #expect(week.day(.saturday)?.session?.start == t(9, 0))
        #expect(week.day(.saturday)?.wake == t(8, 45))
        #expect(week.day(.sunday)?.session?.sessionID == "walk")
    }

    @Test func weekFourSundayIsTheSecondRun() throws {
        #expect(try plan(week: 4, WeekAnswers()).day(.sunday)?.session?.sessionID == "run-2")
    }

    @Test func reducedWeekLeavesOutFullBody() throws {
        let p = try phase1()
        let week = try plan(WeekAnswers(), dropping: Set(p.reducedWeek.drop))
        #expect(week.day(.thursday)?.session == nil)
        #expect(week.days.compactMap(\.session).map(\.sessionID).sorted() == ["run-1", "upper-a", "upper-b", "walk"])
        #expect(week.unplaced.isEmpty)
    }

    @Test func noStartDateMeansNoPlan() throws {
        var p = profile()
        p.programme.startDate = nil
        #expect(try plan(WeekAnswers(), profile: p).days.isEmpty)
    }

    @Test func aWeekAcrossTheClockChangeStillHasSevenDays() throws {
        // Clocks go back on Sunday 25 Oct 2026; start the programme on 19 Oct.
        let p = profile { $0.programme.startDate = date(2026, 10, 19) }
        let week = WeekPlanner.plan(weekStarting: date(2026, 10, 19), programme: try phase1(), profile: p,
                                    answers: WeekAnswers(), calendar: calendar)
        #expect(week.days.map(\.weekday) == Weekday.allCases)
        #expect(calendar.component(.day, from: week.days[6].date) == 25)
        #expect(week.day(.sunday)?.session?.sessionID == "walk")
    }

    @Test func answersRoundTripAsJSON() throws {
        let answers = WeekAnswers(officeDays: [.tuesday, .thursday], earlyStarts: [.tuesday: t(8, 0)])
        let data = try JSONEncoder().encode(answers)
        #expect(try JSONDecoder().decode(WeekAnswers.self, from: data) == answers)
    }
}
