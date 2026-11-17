import Foundation
import Testing
@testable import CoachCore

@Suite struct DayPlanTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 7) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    /// Started on Monday 23 Nov 2026, alarm 06:15 as in the design.
    private func profile(wake: TimeOfDay = TimeOfDay(hour: 6, minute: 15)) -> Profile {
        var p = Profile()
        p.confirmed = true
        p.programme.startDate = date(2026, 11, 23, hour: 0)
        p.schedule.earliestWake = wake
        return p
    }

    @Test func noPlanBeforeOnboarding() throws {
        #expect(DayPlan.make(for: date(2026, 11, 23), programme: try phase1(), profile: Profile(), calendar: calendar) == nil)
    }

    @Test func sleepRuleComesFromTomorrowsAlarm() throws {
        // Tuesday in the office from 08:00: run 06:50, alarm 06:35, so Monday
        // night is lights out 22:50 (7.5 h + 15 min) and wind-down 22:20.
        let answers = WeekAnswers(officeDays: [.tuesday], earlyStarts: [.tuesday: TimeOfDay(hour: 8, minute: 0)])
        let monday = try #require(DayPlan.make(for: date(2026, 11, 23), programme: phase1(), profile: profile(),
                                               answers: { _ in answers }, calendar: calendar))
        #expect(monday.lightsOut == TimeOfDay(hour: 22, minute: 50))
        #expect(monday.windDown == TimeOfDay(hour: 22, minute: 20))
        #expect(monday.timeline.last?.detail == "Lights out 22:50 for a 06:35 alarm")
        let tuesday = try #require(DayPlan.make(for: date(2026, 11, 24), programme: phase1(), profile: profile(),
                                                answers: { _ in answers }, calendar: calendar))
        #expect(tuesday.alarm == TimeOfDay(hour: 6, minute: 35))
        #expect(tuesday.leave == TimeOfDay(hour: 7, minute: 35))
        #expect(tuesday.timeline.map(\.kind) == [.wake, .session, .leave, .windDown])
    }

    @Test func lateAlarmTomorrowCapsLightsOutAtTheLatestBedtime() throws {
        // Home Tuesday: alarm 08:00 would allow 00:15; 23:30 wins.
        let monday = try #require(DayPlan.make(for: date(2026, 11, 23), programme: phase1(), profile: profile(), calendar: calendar))
        #expect(monday.lightsOut == TimeOfDay(hour: 23, minute: 30))
        #expect(monday.windDown == TimeOfDay(hour: 23, minute: 0))
    }

    @Test func todayMatchesTheAlarmThatRings() throws {
        // QA-9: Today's alarm is the planner's wake, the one AlarmSchedule registers.
        let programme = try phase1()
        let plan = try #require(DayPlan.make(for: date(2026, 11, 23), programme: programme, profile: profile(), calendar: calendar))
        let alarms = AlarmSchedule.make(now: date(2026, 11, 23, hour: 0), programme: programme, profile: profile(),
                                        answers: { _ in WeekAnswers() }, calendar: calendar)
        let first = try #require(alarms.first)
        let c = calendar.dateComponents([.hour, .minute], from: first.fireDate)
        #expect(plan.alarm == TimeOfDay(hour: c.hour!, minute: c.minute!))
        #expect(first.title == "Upper A at \(try #require(plan.session).start)")
    }

    @Test func mondayWeekOneIsUpperAAfterTheAlarmWithItsLengthFromTheData() throws {
        let programme = try phase1()
        let plan = try #require(DayPlan.make(for: date(2026, 11, 23), programme: programme, profile: profile(), calendar: calendar))
        let slot = try #require(plan.session)
        #expect(slot.id == "upper-a")
        // Home day: 09:00 − 15 shower − 39 min, rounded down to 08:05; alarm 15 min before.
        #expect(slot.start == TimeOfDay(hour: 8, minute: 5))
        #expect(plan.alarm == TimeOfDay(hour: 7, minute: 50))
        guard case let .strength(upperA) = programme.sessions["upper-a"] else { Issue.record("upper-a"); return }
        #expect(slot.minutes == upperA.durationMinutes[0])
        #expect(slot.end == TimeOfDay(hour: 8, minute: 5).adding(minutes: upperA.durationMinutes[0]))
        #expect(plan.timeline.map(\.kind) == [.wake, .session, .windDown])
    }

    @Test func basketballDayHasNoSessionButShowsTheFixedEvent() throws {
        let plan = try #require(DayPlan.make(for: date(2026, 11, 25), programme: phase1(), profile: profile(), calendar: calendar))
        #expect(plan.session == nil)
        // No session, so no alarm (E11): sleep in.
        #expect(plan.alarm == nil)
        #expect(plan.timeline.map(\.kind) == [.fixed, .windDown])
        #expect(plan.timeline[0].title == "Basketball")
        #expect(plan.timeline[0].detail == "Evening")
    }

    @Test func restDayHasOnlyWakeAndWindDown() throws {
        let plan = try #require(DayPlan.make(for: date(2026, 11, 27), programme: phase1(), profile: profile(), calendar: calendar))
        #expect(plan.planned.entry == .rest)
        #expect(plan.alarm == nil)
        #expect(plan.timeline.map(\.kind) == [.windDown])
    }

    @Test func runWalkLengthComesFromItsWeek() throws {
        let programme = try phase1()
        let plan = try #require(DayPlan.make(for: date(2026, 11, 24), programme: programme, profile: profile(), calendar: calendar))
        guard case let .runWalk(run) = programme.sessions["run-1"] else { Issue.record("run-1"); return }
        #expect(plan.session?.id == "run-1")
        #expect(plan.session?.minutes == run.weeks.first { $0.week == 1 }?.durationMinutes)
    }

    @Test func timesWrapRoundMidnight() {
        #expect(TimeOfDay(hour: 0, minute: 10).adding(minutes: -20) == TimeOfDay(hour: 23, minute: 50))
        #expect(TimeOfDay(hour: 23, minute: 50).adding(minutes: 20) == TimeOfDay(hour: 0, minute: 10))
        #expect(TimeOfDay(hour: 5, minute: 45).adding(minutes: -1440) == TimeOfDay(hour: 5, minute: 45))
    }

    @Test func weekOneStartsOnTheMondayOnOrAfterConfirming() {
        let monday = date(2026, 11, 23, hour: 0)
        #expect(Programme.startDate(confirmedOn: date(2026, 11, 23, hour: 20), calendar: calendar) == monday)
        #expect(Programme.startDate(confirmedOn: date(2026, 11, 17), calendar: calendar) == monday)
        #expect(Programme.startDate(confirmedOn: date(2026, 11, 22, hour: 23), calendar: calendar) == monday)
    }
}
