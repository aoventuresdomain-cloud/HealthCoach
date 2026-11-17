import Foundation
import Testing
@testable import CoachCore

/// AlarmKit stand-in with a clock: alarms that have fired drop off the list,
/// as they do on the phone.
private actor ClockedRegistrar: AlarmRegistering {
    private var alarms: [UUID: Date] = [:]
    private var now: Date
    private(set) var registerCalls = 0
    private(set) var cancelCalls = 0

    init(now: Date) { self.now = now }

    func advance(to date: Date) { now = date }

    func registeredAlarmIDs() async throws -> Set<UUID> {
        Set(alarms.filter { $0.value > now }.keys)
    }

    func register(_ alarm: PlannedAlarm) async throws {
        registerCalls += 1
        alarms[alarm.id] = alarm.fireDate
    }

    func cancel(alarmID: UUID) async throws {
        cancelCalls += 1
        alarms[alarmID] = nil
    }

    /// The furthest registered alarm still to ring.
    func furthest() -> Date? { alarms.values.filter { $0 > now }.max() }
    func upcomingCount() -> Int { alarms.values.filter { $0 > now }.count }
}

/// Board M2-02: 7–14 days of alarms across simulated opens with no owner
/// action, a one-day "tomorrow changed", the empty-plan guard, and QA-1.
@Suite struct AlarmScheduleTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    private func profile(start: Date? = nil) -> Profile {
        var p = Profile()
        p.confirmed = true
        p.programme.startDate = start ?? at(2026, 11, 23)
        return p
    }

    private func make(now: Date, profile: Profile? = nil, answers: WeekAnswers = WeekAnswers(),
                      completed: Set<String> = []) throws -> [PlannedAlarm] {
        AlarmSchedule.make(now: now, programme: try phase1(), profile: profile ?? self.profile(),
                           answers: { _ in answers }, completed: completed, calendar: calendar)
    }

    private func hm(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: c.hour!, minute: c.minute!).description
    }

    // MARK: The 14-day schedule

    @Test func reducedWeekDropsThursdaysFullBodyAlarm() throws {
        let now = at(2026, 11, 23, 5, 0)
        let normal = try make(now: now)
        let reduced = AlarmSchedule.make(now: now, programme: try phase1(), profile: profile(),
                                         answers: { _ in WeekAnswers() }, dropping: ["full-body"], calendar: calendar)
        let thursday = at(2026, 11, 26)
        let before = try #require(normal.first { calendar.isDate($0.fireDate, inSameDayAs: thursday) })
        #expect(before.title.hasPrefix("Full body"))
        // Thursday is still a work day, so it keeps a plain wake alarm, not the session's.
        let after = reduced.first { calendar.isDate($0.fireDate, inSameDayAs: thursday) }
        #expect(after?.title.hasPrefix("Full body") != true)
        #expect(reduced.allSatisfy { !$0.title.hasPrefix("Full body") })
    }

    @Test func fourteenDaysOfWakeAlarms() throws {
        let alarms = try make(now: at(2026, 11, 23, 5, 0))
        // Weeks 1–2: Upper A, run-walk, full body and Upper B, twice. No alarm on
        // basketball Wednesday, the Friday rest day or Sunday's optional walk (E11).
        #expect(alarms.count == 8)
        #expect(alarms.map(\.fireDate) == alarms.map(\.fireDate).sorted())
        #expect(hm(alarms[0].fireDate) == "07:50")
        #expect(alarms[0].title == "Upper A at 08:05")
        #expect(alarms[2].title == "Full body (light legs) at 08:15")
        #expect(calendar.isDate(alarms.last!.fireDate, inSameDayAs: at(2026, 12, 5)))
    }

    @Test func noAlarmOnFreeHomeDaysOrOptionalSessions() throws {
        // QA-11, decision E14: alarms only on days with a fixed start. Week 2,
        // no office days: Wednesday (basketball), Friday (rest) and Sunday
        // (optional walk) ring nothing, and Today agrees with the schedule.
        let programme = try phase1()
        let alarms = try make(now: at(2026, 11, 30, 5, 0))
        for (d, name) in [(2, "Wednesday"), (4, "Friday"), (6, "Sunday walk")] {
            let day = at(2026, 12, d)
            #expect(!alarms.contains { calendar.isDate($0.fireDate, inSameDayAs: day) }, "\(name)")
            let today = try #require(DayPlan.make(for: day, programme: programme, profile: profile(), calendar: calendar))
            #expect(today.alarm == nil, "\(name)")
        }
        // The walk is still planned, just without an alarm.
        let sunday = try #require(DayPlan.make(for: at(2026, 12, 6), programme: programme, profile: profile(), calendar: calendar))
        #expect(sunday.session?.id == "walk")
        // An office Wednesday or Friday still gets a work-day alarm.
        let office = try make(now: at(2026, 11, 30, 5, 0), answers: WeekAnswers(officeDays: [.wednesday, .friday]))
        #expect(office.contains { calendar.isDate($0.fireDate, inSameDayAs: at(2026, 12, 2)) })
        #expect(office.contains { calendar.isDate($0.fireDate, inSameDayAs: at(2026, 12, 4)) })
        // From week 4 Sunday's easy run-walk is not optional, so it rings.
        let weekFour = try make(now: at(2026, 12, 14, 5, 0))
        #expect(weekFour.contains { calendar.isDate($0.fireDate, inSameDayAs: at(2026, 12, 20)) })
    }

    @Test func windDownBeforeAFreeDayFollowsTheWeeksMedianAlarm() throws {
        // E14: Saturday night (before Sunday's free day) keeps a normal bedtime.
        let programme = try phase1()
        func plan(_ d: Int, _ answers: WeekAnswers) throws -> DayPlan {
            try #require(DayPlan.make(for: at(2026, 12, d), programme: programme, profile: profile(),
                                      answers: { _ in answers }, calendar: calendar))
        }
        // No office days: every alarm is late enough that lights out is the 23:30 cap.
        let home = WeekAnswers()
        #expect(try plan(5, home).windDown == plan(2, home).windDown) // Saturday night vs Wednesday night
        // All office: earlier alarms; Saturday night stays within 30 min of the weekday nights.
        let office = WeekAnswers(officeDays: [.monday, .tuesday, .wednesday, .thursday, .friday])
        let saturday = try plan(5, office).lightsOut.minutesSinceMidnight
        for d in 1...3 {
            let weekday = try plan(d, office).lightsOut.minutesSinceMidnight
            #expect(abs(saturday - weekday) <= 30, "Sat \(saturday) vs \(d) Dec \(weekday)")
        }
    }

    @Test func alarmsAlreadyPastTodayAreLeftOut() throws {
        let alarms = try make(now: at(2026, 11, 23, 12, 0))
        #expect(alarms.count == 7)
        #expect(alarms.allSatisfy { $0.fireDate > at(2026, 11, 23, 12, 0) })
    }

    @Test func idsAreStableAcrossOpens() throws {
        let morning = try make(now: at(2026, 11, 23, 5, 0))
        // Monday's Upper A was done (logged), so nothing moves (E13).
        let evening = try make(now: at(2026, 11, 23, 21, 0), completed: ["upper-a"])
        // Same horizon (today + 13 days); only Monday's alarm has passed by the evening.
        #expect(evening.count == 7)
        let shared = Set(morning.dropFirst().map(\.id)).intersection(evening.map(\.id))
        #expect(shared.count == 7)
    }

    @Test func clockChangeKeepsLocalWakeTimes() throws {
        // Clocks go back on Sunday 25 Oct 2026.
        let p = profile(start: at(2026, 10, 19))
        let alarms = try make(now: at(2026, 10, 24, 12, 0), profile: p)
        let monday = try #require(alarms.first { calendar.isDate($0.fireDate, inSameDayAs: at(2026, 10, 26)) })
        // Week 2 Upper A is 45 min: 09:00 − 15 − 45 = 08:00 start, 07:45 alarm, in GMT now.
        #expect(hm(monday.fireDate) == "07:45")
    }

    // MARK: Simulated opens, no owner action

    @Test func opensKeepSevenToFourteenDaysSet() async throws {
        let programme = try phase1()
        let p = profile()
        let start = at(2026, 11, 23, 12, 0)
        let registrar = ClockedRegistrar(now: start)
        // Opens on these days (noon), including a full week away from the app.
        for dayOffset in [0, 1, 2, 5, 9, 16, 17] {
            let now = calendar.date(byAdding: .day, value: dayOffset, to: start)!
            await registrar.advance(to: now)
            if dayOffset > 0, let before = await registrar.furthest() {
                // Even after a full week away, about 6 more days were still set.
                #expect(before.timeIntervalSince(now) >= 5 * 86_400, "day \(dayOffset)")
            }
            let planned = AlarmSchedule.make(now: now, programme: programme, profile: p,
                                             answers: { _ in WeekAnswers(officeDays: [.tuesday, .thursday]) },
                                             calendar: calendar)
            let outcome = try await AlarmReconciler.reconcile(planned: planned, using: registrar, now: now)
            #expect(AlarmCoverage(outcome).needsWarning == false)
            let furthest = try #require(await registrar.furthest())
            // Alarms are on training days only (E11), so the last one is at most
            // two days short of the 14-day horizon.
            #expect(furthest.timeIntervalSince(now) >= 10 * 86_400, "day \(dayOffset)")
            #expect(furthest.timeIntervalSince(now) <= 14 * 86_400, "day \(dayOffset)")
            #expect(await registrar.upcomingCount() == planned.count)
        }
    }

    @Test func aSecondOpenTheSameDayChangesNothing() async throws {
        let now = at(2026, 11, 23, 6, 0)
        let registrar = ClockedRegistrar(now: now)
        _ = try await AlarmReconciler.reconcile(planned: try make(now: now), using: registrar, now: now)
        let calls = await registrar.registerCalls
        let later = at(2026, 11, 23, 6, 30)
        await registrar.advance(to: later)
        let outcome = try await AlarmReconciler.reconcile(planned: try make(now: later), using: registrar, now: later)
        #expect(outcome.reSet == 0)
        #expect(outcome.cancelled == 0)
        #expect(await registrar.registerCalls == calls)
    }

    // MARK: Tomorrow changed

    @Test func tomorrowChangedReplansOneDayOnly() throws {
        let programme = try phase1()
        let p = profile()
        let now = at(2026, 11, 23, 20, 0)
        let current = try make(now: now)
        // Tuesday turns into an office day with an 08:00 start.
        let changed = WeekAnswers(officeDays: [.tuesday], earlyStarts: [.tuesday: TimeOfDay(hour: 8, minute: 0)])
        let week = WeekPlanner.plan(weekStarting: at(2026, 11, 23), programme: programme, profile: p,
                                    answers: changed, calendar: calendar)
        let updated = AlarmSchedule.replacingDay(at(2026, 11, 24), in: current, from: week,
                                                 programme: programme, calendar: calendar)
        let diff = AlarmReconciler.plan(planned: updated, registered: Set(current.map(\.id)), now: now)
        #expect(diff.toRegister.count == 1)
        #expect(diff.toCancel.count == 1)
        let tuesday = try #require(diff.toRegister.first)
        #expect(calendar.isDate(tuesday.fireDate, inSameDayAs: at(2026, 11, 24)))
        // 08:00 − 25 − 15 − 28 (run-1) = 06:52 → 06:50, alarm 06:35.
        #expect(hm(tuesday.fireDate) == "06:35")
        #expect(updated.count == current.count)
    }

    // MARK: Empty-plan guard and QA-1

    @Test func noStartDateMeansNoPlanAndNothingCancelled() async throws {
        var p = profile()
        p.programme.startDate = nil
        let now = at(2026, 11, 23, 6, 0)
        #expect(try make(now: now, profile: p).isEmpty)

        let registrar = ClockedRegistrar(now: now)
        _ = try await AlarmReconciler.reconcile(planned: try make(now: now), using: registrar, now: now)
        let outcome = try await AlarmReconciler.reconcile(planned: [], using: registrar, now: now)
        #expect(outcome.cancelled == 0)
        #expect(await registrar.upcomingCount() == 8)
        #expect(AlarmCoverage(outcome) == .noAlarms)
    }

    @Test func zeroUpcomingAlarmsIsAlwaysAWarning() {
        let none = ReconcileOutcome(total: 0, reSet: 0, cancelled: 0, next: nil)
        #expect(AlarmCoverage(none) == .noAlarms)
        #expect(AlarmCoverage(none).needsWarning)
        let next = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(AlarmCoverage(ReconcileOutcome(total: 14, reSet: 0, cancelled: 0, next: next)) == .allSet(count: 14, next: next))
        #expect(AlarmCoverage(ReconcileOutcome(total: 14, reSet: 3, cancelled: 0, next: next)) == .reSet(missing: 3, total: 14, next: next))
    }

    // MARK: Stable ids

    @Test func stableUUIDsDependOnlyOnTheText() {
        #expect(UUID(stableFrom: "wake|2026-11-24|06:35") == UUID(stableFrom: "wake|2026-11-24|06:35"))
        #expect(UUID(stableFrom: "wake|2026-11-24|06:35") != UUID(stableFrom: "wake|2026-11-24|06:40"))
        #expect(UUID(stableFrom: "x").uuidString.dropFirst(14).first == "8")
    }
}
