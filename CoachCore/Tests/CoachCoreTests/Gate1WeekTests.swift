import Foundation
import Testing
@testable import CoachCore

/// Gate 1 §A (docs/qa/gate-1-checklist.md): the CoachCore twin of the
/// simulated week. Same as the `week2-hybrid` UI fixture: paper start Mon 16 Nov
/// 2026, so 23–29 Nov is week 2; office Mon, Tue and Thu; early Tue 08:00;
/// late Thu 19:00; onboarded Sun 22 Nov 18:00. Weeks after it reuse its
/// answers, as the app does.
@Suite struct Gate1WeekTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func at(_ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: h, minute: min))!
    }

    private static func t(_ h: Int, _ m: Int) -> TimeOfDay { TimeOfDay(hour: h, minute: m) }

    static let hybrid = WeekAnswers(officeDays: [.monday, .tuesday, .thursday],
                                    earlyStarts: [.tuesday: t(8, 0)],
                                    lateFinishes: [.thursday: t(19, 0)])

    private func answers(_ monday: Date) -> WeekAnswers {
        monday >= at(11, 23) ? Self.hybrid : WeekAnswers()
    }

    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    private func profile() -> Profile {
        var p = Profile()
        p.confirmed = true
        p.programme.startDate = at(11, 16)
        p.programme.confirmedOn = at(11, 22, 18)
        return p
    }

    private func today(_ now: Date, done: Set<String> = []) throws -> DayPlan {
        try #require(DayPlan.make(for: now, programme: phase1(), profile: profile(), answers: answers,
                                  now: now, completed: done, calendar: calendar))
    }

    private func alarms(_ now: Date, done: Set<String> = []) throws -> [PlannedAlarm] {
        AlarmSchedule.make(now: now, programme: try phase1(), profile: profile(), answers: answers,
                           completed: done, calendar: calendar)
    }

    /// The alarm time on `date`, if one rings that day.
    private func ring(on date: Date, in alarms: [PlannedAlarm]) -> TimeOfDay? {
        alarms.first { calendar.isDate($0.fireDate, inSameDayAs: date) }.map {
            let c = calendar.dateComponents([.hour, .minute], from: $0.fireDate)
            return Self.t(c.hour!, c.minute!)
        }
    }

    @Test func a2AlarmsAfterTheSundayPrompt() throws {
        // Sun 22 Nov 18:01: 7–14 days registered, only on session or office days (E14).
        let set = try alarms(at(11, 22, 18, 1))
        #expect((7...14).contains(set.count), "\(set.count) alarms")
        let week = (23...29).filter { ring(on: at(11, $0), in: set) != nil }
        #expect(week == [23, 24, 26, 28], "alarm days \(week)") // Mon, Tue, Thu, Sat
    }

    @Test func a3MondayUpperAWithLeaveTime() throws {
        let plan = try today(at(11, 23, 6, 30))
        #expect(plan.session?.id == "upper-a")
        #expect(plan.alarm != nil)
        #expect(plan.alarm == ring(on: at(11, 23), in: try alarms(at(11, 22, 18, 1))))
        #expect(plan.leave != nil)
    }

    @Test func a5TuesdayRunWithTheEarlyStart() throws {
        let plan = try today(at(11, 24, 7), done: ["upper-a"])
        #expect(plan.session?.id == "run-1")
        #expect(plan.alarm == ring(on: at(11, 24), in: try alarms(at(11, 23, 21), done: ["upper-a"])))
        // The 08:00 meeting: leave by 08:00 − commute.
        let leave = try #require(plan.leave)
        #expect(leave < Self.t(8, 0))
    }

    @Test func a7WednesdayIsRestWithNoAlarm() throws {
        let plan = try today(at(11, 25, 7), done: ["upper-a", "run-1"])
        #expect(plan.session == nil)
        #expect(plan.alarm == nil)
        // Tonight's wind-down comes from Thursday's alarm.
        let thursday = try #require(try today(at(11, 26, 6), done: ["upper-a", "run-1"]).alarm)
        let lightsOut = WeekPlanner.lightsOut(forWake: thursday.minutesSinceMidnight, schedule: profile().schedule)
        #expect(plan.lightsOut == lightsOut)
    }

    @Test func a8a9MissedThursdayMovesToFridayAndKeepsItsAlarm() throws {
        let done: Set<String> = ["upper-a", "run-1"]
        // Thu 21:00, full body not logged: too late tonight, so Friday (free, legal).
        let thursdayNight = try phase1Plan(now: at(11, 26, 21), done: done)
        #expect(thursdayNight.day(.thursday)?.session == nil)
        let friday = try #require(thursdayNight.day(.friday)?.session)
        #expect(friday.sessionID == "full-body")
        #expect(friday.movedFrom == .thursday)
        #expect(friday.start == Self.t(8, 5)) // Friday morning, not the evening
        let setThursdayNight = try #require(ring(on: at(11, 27), in: try alarms(at(11, 26, 21), done: done)))
        // Fri 07:00 (QA-15): same day, same start, same alarm as Thursday night set.
        let fridayMorning = try today(at(11, 27, 7), done: done)
        #expect(fridayMorning.session?.id == "full-body")
        #expect(fridayMorning.session?.start == Self.t(8, 5))
        #expect(fridayMorning.session?.movedFrom == .thursday)
        #expect(fridayMorning.alarm == setThursdayNight)
        // The reconcile at Fri 07:00 keeps that alarm, and it matches Today.
        #expect(ring(on: at(11, 27), in: try alarms(at(11, 27, 7), done: done)) == setThursdayNight)
    }

    @Test func a10a11TheWeekend() throws {
        let done: Set<String> = ["upper-a", "run-1", "full-body"]
        let saturday = try today(at(11, 28, 7), done: done)
        #expect(saturday.session?.id == "upper-b")
        #expect(saturday.session?.start == profile().schedule.dayOffSessionStart)
        let sunday = try today(at(11, 29, 7), done: done + ["upper-b"])
        #expect(sunday.session?.id == "walk")
        #expect(sunday.alarm == nil)
    }

    // QA-28: Today's current row is the first one not over yet, whatever rows the day has.

    private func current(_ plan: DayPlan, at time: TimeOfDay) -> DayPlan.TimelineItem.Kind? {
        let index = plan.timelineProgress(at: time)
        return index < plan.timeline.count ? plan.timeline[index].kind : nil
    }

    @Test func qa28ThursdayNightAfterTheMoveIsWindDown() throws {
        // A8: full body moved to Friday, so Thursday is wake 08:05, leave 08:35, wind down 23:00.
        let plan = try today(at(11, 26, 21), done: ["upper-a", "run-1"])
        #expect(plan.timeline.map(\.kind) == [.wake, .leave, .windDown])
        #expect(current(plan, at: Self.t(21, 0)) == .windDown)
        #expect(plan.timelineProgress(at: Self.t(21, 0)) == 2) // wake and leave both past
    }

    @Test func qa28AnOrdinaryDayStepsThroughEveryRow() throws {
        // Monday: wake 07:20, Upper A 07:35, leave 08:35, wind down 22:20.
        let plan = try today(at(11, 23, 6, 30))
        #expect(plan.timeline.map(\.kind) == [.wake, .session, .leave, .windDown])
        let session = try #require(plan.session?.end)
        #expect(current(plan, at: Self.t(6, 30)) == .wake)       // nothing past yet
        #expect(current(plan, at: Self.t(7, 20)) == .wake)       // the alarm's minute
        #expect(current(plan, at: Self.t(7, 21)) == .session)    // up next
        #expect(current(plan, at: Self.t(7, 50)) == .session)    // in progress
        #expect(current(plan, at: session) == .leave)            // done, leave next
        #expect(current(plan, at: Self.t(12, 0)) == .windDown)   // leave passed
        #expect(current(plan, at: plan.windDown) == .windDown)   // winding down until lights out
        #expect(current(plan, at: plan.lightsOut) == nil)        // the day is over: all past
    }

    @Test func qa28UntimedEveningEventStaysCurrentUntilWindDown() throws {
        // Wednesday: basketball (evening, no time) then wind down.
        let plan = try today(at(11, 25, 7), done: ["upper-a", "run-1"])
        #expect(plan.timeline.map(\.kind) == [.fixed, .windDown])
        #expect(current(plan, at: Self.t(7, 0)) == .fixed)
        #expect(current(plan, at: plan.windDown.adding(minutes: -1)) == .fixed)
        #expect(current(plan, at: plan.windDown) == .windDown)
        #expect(current(plan, at: plan.lightsOut) == nil)
    }

    private func phase1Plan(now: Date, done: Set<String>) throws -> WeekPlan {
        WeekPlanner.plan(weekStarting: at(11, 23), programme: try phase1(), profile: profile(),
                         answers: Self.hybrid, now: now, completed: done, calendar: calendar)
    }
}

private func + (lhs: Set<String>, rhs: [String]) -> Set<String> { lhs.union(rhs) }
