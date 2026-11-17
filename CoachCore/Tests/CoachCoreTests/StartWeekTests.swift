import Foundation
import Testing
@testable import CoachCore

/// Decision E13 (Advisor ruling on QA-14): the week comes from the paper start
/// date, and a session whose time has passed moves to this evening, else the
/// next free legal day this week, else it is dropped quietly.
@Suite struct StartWeekTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func at(_ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: h, minute: min))!
    }

    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    /// Paper start Monday 16 Nov 2026 (the onboarding guess), so Monday 23 Nov is week 2.
    private func profile() -> Profile {
        var p = Profile()
        p.confirmed = true
        p.programme.startDate = at(11, 16)
        return p
    }

    private func plan(now: Date, answers: WeekAnswers = WeekAnswers(), completed: Set<String> = []) throws -> WeekPlan {
        WeekPlanner.plan(weekStarting: AlarmSchedule.mondayOf(now, calendar: calendar), programme: try phase1(),
                         profile: profile(), answers: answers, now: now, completed: completed, calendar: calendar)
    }

    @Test func weekComesFromThePaperStart() throws {
        let day = try phase1().plannedDay(on: at(11, 23), start: at(11, 16), calendar: calendar)
        #expect(day.week == 2)
        #expect(!day.heldAtLastWeek)
    }

    @Test func onboardingAtTenMondayPutsUpperAOnMondayEvening() throws {
        // Upper A's 08:05 slot has passed at 10:00; tonight 18:00 ends well before wind-down.
        let monday = try #require(try plan(now: at(11, 23, 10)).day(.monday))
        let session = try #require(monday.session)
        #expect(session.sessionID == "upper-a")
        #expect(session.slot == .evening)
        #expect(session.start == TimeOfDay(hour: 18, minute: 0))
        // The other sessions stay where they were.
        let week = try plan(now: at(11, 23, 10))
        #expect(week.day(.tuesday)?.session?.sessionID == "run-1")
        #expect(week.day(.friday)?.session == nil)
    }

    @Test func onboardingAtNineInTheEveningMovesUpperAToFriday() throws {
        // 21:00 + 45 min ends inside the 2 h before wind-down, so the next free
        // legal day: Tuesday run, Wednesday never, Thursday full body, so Friday.
        let week = try plan(now: at(11, 23, 21))
        #expect(week.day(.monday)?.session == nil)
        let friday = try #require(week.day(.friday)?.session)
        #expect(friday.sessionID == "upper-a")
        #expect(friday.movedFrom == .monday)
        #expect(week.unplaced.isEmpty)
        // Friday now has a session, so it gets an alarm (E14), and so does the 14-day schedule.
        #expect(week.day(.friday)?.wake != nil)
        let alarms = AlarmSchedule.make(now: at(11, 23, 21), programme: try phase1(), profile: profile(),
                                        answers: { _ in WeekAnswers() }, calendar: calendar)
        #expect(alarms.contains { calendar.isDate($0.fireDate, inSameDayAs: at(11, 27)) && $0.title.hasPrefix("Upper A") })
    }

    @Test func aDoneSessionDoesNotMove() throws {
        let week = try plan(now: at(11, 23, 21), completed: ["upper-a"])
        #expect(week.day(.monday)?.session?.sessionID == "upper-a")
        #expect(week.day(.friday)?.session == nil)
    }

    @Test func noFreeDayLeftMeansDroppedQuietly() throws {
        // Saturday night: Upper B's 09:00 slot has passed, the evening is too late,
        // and Sunday has its own session. Never carried into next week.
        let week = try plan(now: at(11, 28, 21), completed: ["upper-a", "run-1", "full-body"])
        #expect(week.day(.saturday)?.session == nil)
        #expect(week.day(.sunday)?.session?.sessionID == "walk")
        #expect(week.unplaced.map(\.sessionID) == ["upper-b"])
    }

    @Test func aFutureSessionTodayStaysPut() throws {
        let monday = try #require(try plan(now: at(11, 23, 7)).day(.monday))
        #expect(monday.session?.start == TimeOfDay(hour: 8, minute: 0)) // week 2 Upper A is 45 min
        #expect(monday.session?.slot == .morning)
    }

    @Test func pastWeekSixHoldsAtWeekSix() throws {
        let day = try phase1().plannedDay(on: at(12, 28), start: at(11, 16), calendar: calendar)
        #expect(day.week == 6)
        #expect(day.heldAtLastWeek)
    }

    @Test func todayFollowsTheMove() throws {
        let today = try #require(DayPlan.make(for: at(11, 23, 10), programme: phase1(), profile: profile(),
                                              now: at(11, 23, 10), calendar: calendar))
        #expect(today.session?.start == TimeOfDay(hour: 18, minute: 0))
    }
}

extension StartWeekTests {
    @Test func openingJustAfterTheAlarmNeverMovesTheSession() throws {
        // Week 2 Upper A runs 08:00–08:45; at 08:10 it's still on, so it stays.
        let monday = try #require(try plan(now: at(11, 23, 8, 10)).day(.monday))
        #expect(monday.session?.start == TimeOfDay(hour: 8, minute: 0))
    }
}

/// QA-15: a move lasts beyond the day it was made. The planner is stateless, so
/// every unlogged session on an earlier day is replayed as passed.
extension StartWeekTests {
    @Test func mondaysMoveToFridaySurvivesTuesdayMorning() throws {
        // Monday 21:00 moved Upper A to Friday; Tuesday 07:00 must agree.
        let week = try plan(now: at(11, 24, 7))
        #expect(week.day(.monday)?.session == nil)
        let friday = try #require(week.day(.friday)?.session)
        #expect(friday.sessionID == "upper-a")
        #expect(friday.movedFrom == .monday)
        // Tuesday's own run is still ahead, so it stays.
        #expect(week.day(.tuesday)?.session?.sessionID == "run-1")
        #expect(week.unplaced.isEmpty)
    }

    @Test func fridaysAlarmSurvivesLaterReconciles() throws {
        let programme = try phase1()
        let cases: [(now: Date, done: Set<String>)] = [(at(11, 24, 7), []), (at(11, 26, 21), ["run-1", "full-body"])]
        for (now, done) in cases {
            let alarms = AlarmSchedule.make(now: now, programme: programme, profile: profile(),
                                            answers: { _ in WeekAnswers() }, completed: done, calendar: calendar)
            #expect(alarms.contains { calendar.isDate($0.fireDate, inSameDayAs: at(11, 27)) && $0.title.hasPrefix("Upper A") },
                    "\(now): Friday's Upper A alarm is gone")
        }
    }

    @Test func aSessionLoggedOnAnotherDayCountsAsDone() throws {
        // Upper A done on Tuesday evening, not Monday: it doesn't move again.
        let log = SessionLog(programmeID: "phase-1", sessionID: "upper-a", week: 2, startedAt: at(11, 24, 19))
        let done = SessionLog.sessionIDs(in: [log], weekOf: at(11, 26, 7), calendar: calendar)
        #expect(done == ["upper-a"])
        let week = try plan(now: at(11, 26, 7), completed: done)
        #expect(week.day(.monday)?.session?.sessionID == "upper-a")
        #expect(week.day(.friday)?.session?.sessionID != "upper-a")
        // A log from last week doesn't count for this one.
        #expect(SessionLog.sessionIDs(in: [log], weekOf: at(12, 1), calendar: calendar).isEmpty)
    }

    @Test func passedSessionsArePlacedInDayOrder() throws {
        // Thursday 21:00, nothing logged: Monday's Upper A takes Friday, then
        // Tuesday's run and Thursday's full body find no legal day left.
        let week = try plan(now: at(11, 26, 21))
        #expect(week.day(.friday)?.session?.sessionID == "upper-a")
        #expect(week.unplaced.map(\.sessionID) == ["run-1", "full-body"])
        #expect(week.day(.saturday)?.session?.sessionID == "upper-b")
    }
}

/// QA-16: the evening slot is the normal evening start, never the clock.
extension StartWeekTests {
    @Test func theEveningSlotDoesNotChaseTheClock() throws {
        for hour in [(17, 0), (18, 0), (18, 30)] {
            let monday = try #require(try plan(now: at(11, 23, hour.0, hour.1)).day(.monday)?.session)
            #expect(monday.start == TimeOfDay(hour: 18, minute: 0), "at \(hour)")
            #expect(monday.slot == .evening)
        }
        // Once 18:00–18:45 is over unlogged, it has passed again: Friday.
        let week = try plan(now: at(11, 23, 18, 50))
        #expect(week.day(.monday)?.session == nil)
        #expect(week.day(.friday)?.session?.sessionID == "upper-a")
    }
}
