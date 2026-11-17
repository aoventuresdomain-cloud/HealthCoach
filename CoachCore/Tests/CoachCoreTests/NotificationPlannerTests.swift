import Foundation
import Testing
@testable import CoachCore

/// Board M2-05: no notification fires in quiet hours, 22:30–06:00 (plan §4.7).
@Suite struct NotificationPlannerTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func t(_ h: Int, _ m: Int) -> TimeOfDay { TimeOfDay(hour: h, minute: m) }

    private func day(_ date: Date, wake: TimeOfDay? = TimeOfDay(hour: 7, minute: 0), leave: TimeOfDay? = nil,
                     lightsOut: TimeOfDay? = TimeOfDay(hour: 22, minute: 30),
                     session: WeekPlan.Placement? = nil) -> WeekPlan.Day {
        WeekPlan.Day(date: date, weekday: Weekday(calendarWeekday: calendar.component(.weekday, from: date)),
                     week: 1, kind: leave == nil ? .home : .office, session: session, fixed: nil,
                     wake: wake, leave: leave, lightsOutBefore: lightsOut)
    }

    private func plan(_ days: [WeekPlan.Day], now: Date) -> [CoachNotification] {
        NotificationPlanner.plan(days: days, sessionName: { $0 == "upper-a" ? "Upper A" : $0 },
                                 now: now, calendar: calendar)
    }

    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    // MARK: Quiet hours

    @Test func quietHoursRunFromTenThirtyToSix() {
        #expect(!QuietHours.contains(t(22, 29)))
        #expect(QuietHours.contains(t(22, 30)))
        #expect(QuietHours.contains(t(0, 0)))
        #expect(QuietHours.contains(t(5, 59)))
        #expect(!QuietHours.contains(t(6, 0)))
        #expect(!QuietHours.contains(t(12, 0)))
    }

    @Test func nextAllowedIsSixTheFollowingMorning() {
        #expect(QuietHours.nextAllowed(after: date(2026, 11, 23, 23, 0), calendar: calendar) == date(2026, 11, 24, 6, 0))
        #expect(QuietHours.nextAllowed(after: date(2026, 11, 24, 5, 45), calendar: calendar) == date(2026, 11, 24, 6, 0))
        #expect(QuietHours.nextAllowed(after: date(2026, 11, 24, 7, 0), calendar: calendar) == date(2026, 11, 24, 7, 0))
    }

    @Test func lastAllowedIsTwentyFivePastTenThatEvening() {
        #expect(QuietHours.lastAllowed(before: date(2026, 11, 23, 23, 0), calendar: calendar) == date(2026, 11, 23, 22, 25))
        #expect(QuietHours.lastAllowed(before: date(2026, 11, 24, 0, 30), calendar: calendar) == date(2026, 11, 23, 22, 25))
    }

    // MARK: Each kind

    @Test func anEarlyBriefWaitsUntilSix() {
        // 05:45 is the earliest wake the planner allows.
        let monday = date(2026, 11, 23)
        let out = plan([day(monday, wake: t(5, 45), lightsOut: nil)], now: date(2026, 11, 22, 12, 0))
        #expect(out.first { $0.kind == .morningBrief }?.fireDate == date(2026, 11, 23, 6, 0))
    }

    @Test func aLateWindDownComesEarlyInstead() {
        // Lights out 23:30 → wind-down 23:00, inside quiet hours → 22:25 the evening before.
        let tuesday = date(2026, 11, 24)
        let out = plan([day(tuesday, wake: nil, lightsOut: t(23, 30))], now: date(2026, 11, 22))
        #expect(out.map(\.fireDate) == [date(2026, 11, 23, 22, 25)])
        #expect(out.first?.body == "Lights out at 23:30. Screens off soon.")
    }

    @Test func windDownAfterMidnightBelongsToTheNightBefore() {
        // Lights out 00:15 (after midnight on the day itself) still winds down the evening before.
        let tuesday = date(2026, 11, 24)
        let out = plan([day(tuesday, wake: nil, lightsOut: t(0, 15))], now: date(2026, 11, 22))
        #expect(out.map(\.fireDate) == [date(2026, 11, 23, 22, 25)])
    }

    @Test func anEarlyWindDownIsLeftAlone() {
        let tuesday = date(2026, 11, 24)
        let out = plan([day(tuesday, wake: nil, lightsOut: t(22, 15))], now: date(2026, 11, 22))
        #expect(out.map(\.fireDate) == [date(2026, 11, 23, 21, 45)])
    }

    @Test func leaveNowInQuietHoursIsDropped() {
        let monday = date(2026, 11, 23)
        let out = plan([day(monday, wake: nil, leave: t(5, 50), lightsOut: nil)], now: date(2026, 11, 22))
        #expect(out.isEmpty)
    }

    @Test func briefNamesTheSessionAndTheLeaveTime() {
        let monday = date(2026, 11, 23)
        let session = WeekPlan.Placement(sessionID: "upper-a", slot: .morning, start: t(7, 40), end: t(8, 19), movedFrom: nil)
        let out = plan([day(monday, wake: t(7, 25), leave: t(8, 35), lightsOut: nil, session: session)],
                       now: date(2026, 11, 22))
        #expect(out.map(\.kind) == [.morningBrief, .leaveNow])
        #expect(out.first?.body == "Upper A at 07:40, leave at 08:35.")
        #expect(out.first?.id == "morningBrief-2026-11-23")
    }

    @Test func sundayPromptAtSixInTheEvening() {
        let sunday = date(2026, 11, 29)
        let out = plan([day(sunday, wake: nil, lightsOut: nil)], now: date(2026, 11, 28))
        #expect(out.map(\.kind) == [.sundayPrompt])
        #expect(out.first?.fireDate == date(2026, 11, 29, 18, 0))
    }

    @Test func nothingInThePast() {
        let monday = date(2026, 11, 23)
        let out = plan([day(monday, wake: t(7, 0), lightsOut: t(22, 30))], now: date(2026, 11, 23, 6, 30))
        // Wind-down (22:00 Sunday) has passed; the 07:00 brief has not.
        #expect(out.map(\.kind) == [.morningBrief])
    }

    // MARK: Clock changes

    @Test func clockChangeKeepsWallClockTimes() {
        // UK clocks go forward on Sunday 29 March 2026 and back on Sunday 25 October 2026.
        for (y, m, d) in [(2026, 3, 29), (2026, 3, 30), (2026, 10, 25), (2026, 10, 26)] {
            let out = plan([day(date(y, m, d), wake: t(7, 0), lightsOut: t(23, 0))], now: date(2026, 1, 1))
            let brief = out.first { $0.kind == .morningBrief }
            #expect(brief?.fireDate == date(y, m, d, 7, 0))
            let windDown = out.first { $0.kind == .windDown }
            let evening = calendar.date(byAdding: .day, value: -1, to: date(y, m, d))!
            #expect(windDown?.fireDate == calendar.date(bySettingHour: 22, minute: 25, second: 0, of: evening))
            for n in out { #expect(!QuietHours.contains(n.fireDate, calendar: calendar)) }
        }
    }

    // MARK: Whole weeks from the planner

    @Test func noPlannedWeekEverFiresInQuietHours() throws {
        let programme = try phase1()
        var profile = Profile()
        profile.confirmed = true
        profile.programme.startDate = date(2026, 11, 23)
        let answerSets: [WeekAnswers] = [
            WeekAnswers(),
            WeekAnswers(officeDays: [.monday, .tuesday, .thursday]),
            WeekAnswers(officeDays: Set(Weekday.allCases), earlyStarts: [.monday: t(7, 30), .thursday: t(8, 0)],
                        lateFinishes: [.tuesday: t(19, 30)]),
        ]
        for answers in answerSets {
            for week in 0..<4 {
                let monday = calendar.date(byAdding: .day, value: 7 * week, to: date(2026, 11, 23))!
                let days = WeekPlanner.plan(weekStarting: monday, programme: programme, profile: profile,
                                            answers: answers, calendar: calendar).days
                let out = NotificationPlanner.plan(days: days, sessionName: { programme.sessions[$0]?.name ?? $0 },
                                                   now: date(2026, 11, 1), calendar: calendar)
                #expect(!out.isEmpty)
                for n in out {
                    #expect(!QuietHours.contains(n.fireDate, calendar: calendar), "\(n.id) at \(n.fireDate)")
                }
                #expect(Set(out.map(\.id)).count == out.count)
            }
        }
    }

    @Test func fourteenDaysFromNowLikeTheAlarms() throws {
        let programme = try phase1()
        var profile = Profile()
        profile.confirmed = true
        profile.programme.startDate = date(2026, 11, 23)
        // Wednesday of week 1, mid-morning.
        let now = date(2026, 11, 25, 10, 0)
        let out = NotificationPlanner.plan(now: now, programme: programme, profile: profile,
                                           answers: { _ in WeekAnswers(officeDays: [.monday, .thursday]) },
                                           calendar: calendar)
        let first = try #require(out.first)
        let last = try #require(out.last)
        #expect(first.fireDate > now)
        #expect(last.fireDate < date(2026, 12, 9))
        #expect(out.contains { $0.id == "sundayPrompt-2026-11-29" })
        #expect(out.contains { $0.id == "sundayPrompt-2026-12-06" })
        #expect(out.contains { $0.id == "leaveNow-2026-11-26" })
        for n in out { #expect(!QuietHours.contains(n.fireDate, calendar: calendar)) }
    }

    @Test func noStartDateNoNotifications() throws {
        let out = NotificationPlanner.plan(now: date(2026, 11, 25), programme: try phase1(), profile: Profile(),
                                           answers: { _ in WeekAnswers() }, calendar: calendar)
        #expect(out.isEmpty)
    }

    @Test func neverMoreThanIOSKeeps() {
        let days = (0..<30).map { day(calendar.date(byAdding: .day, value: $0, to: date(2026, 11, 23))!,
                                      leave: t(8, 30)) }
        let out = plan(days, now: date(2026, 11, 22))
        #expect(out.count == NotificationPlanner.pendingLimit)
        #expect(out.map(\.fireDate) == out.map(\.fireDate).sorted())
    }
}
