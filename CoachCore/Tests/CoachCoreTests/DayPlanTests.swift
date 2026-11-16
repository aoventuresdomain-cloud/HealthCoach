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

    @Test func sleepRuleMatchesTheDesign() throws {
        // 06:15 alarm → lights out 22:30, wind-down 22:00 (README, Today).
        let plan = try #require(DayPlan.make(for: date(2026, 11, 23), programme: phase1(), profile: profile(), calendar: calendar))
        #expect(plan.alarm == TimeOfDay(hour: 6, minute: 15))
        #expect(plan.lightsOut == TimeOfDay(hour: 22, minute: 30))
        #expect(plan.windDown == TimeOfDay(hour: 22, minute: 0))
    }

    @Test func mondayWeekOneIsUpperAAfterTheAlarmWithItsLengthFromTheData() throws {
        let programme = try phase1()
        let plan = try #require(DayPlan.make(for: date(2026, 11, 23), programme: programme, profile: profile(), calendar: calendar))
        let slot = try #require(plan.session)
        #expect(slot.id == "upper-a")
        #expect(slot.start == TimeOfDay(hour: 6, minute: 30))
        guard case let .strength(upperA) = programme.sessions["upper-a"] else { Issue.record("upper-a"); return }
        #expect(slot.minutes == upperA.durationMinutes[0])
        #expect(slot.end == TimeOfDay(hour: 6, minute: 30).adding(minutes: upperA.durationMinutes[0]))
        #expect(plan.timeline.map(\.kind) == [.wake, .session, .windDown])
    }

    @Test func basketballDayHasNoSessionButShowsTheFixedEvent() throws {
        let plan = try #require(DayPlan.make(for: date(2026, 11, 25), programme: phase1(), profile: profile(), calendar: calendar))
        #expect(plan.session == nil)
        #expect(plan.timeline.map(\.kind) == [.wake, .fixed, .windDown])
        #expect(plan.timeline[1].title == "Basketball")
        #expect(plan.timeline[1].detail == "Evening")
    }

    @Test func restDayHasOnlyWakeAndWindDown() throws {
        let plan = try #require(DayPlan.make(for: date(2026, 11, 27), programme: phase1(), profile: profile(), calendar: calendar))
        #expect(plan.planned.entry == .rest)
        #expect(plan.timeline.map(\.kind) == [.wake, .windDown])
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
