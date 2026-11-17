import Foundation
import Testing
@testable import CoachCore

/// Gate 1–2 checklist §A, the CoachCore twin for the planner steps (A2, A3,
/// A7–A11) of the scripted hybrid week 2 (Mon 23 – Sun 29 Nov 2026): office
/// Mon, Tue, Thu; early Tue 08:00; late Thu 19:00. Upper A and Run 1 are
/// logged; Thursday's full body is missed and passes at 21:00.
/// The coach steps (A5, A13, A16, A17) are in `Week2HybridCoachTests`.
@Suite struct Week2HybridPlannerTests {
    let f = CoachFixture()

    private let answers = WeekAnswers(officeDays: [.monday, .tuesday, .thursday],
                                      earlyStarts: [.tuesday: TimeOfDay(hour: 8, minute: 0)],
                                      lateFinishes: [.thursday: TimeOfDay(hour: 19, minute: 0)])

    /// Onboarded on paper start day, so nothing earlier is replayed.
    private func profile() -> Profile {
        var p = f.profile()
        p.programme.confirmedOn = f.day(0, hour: 9)
        return p
    }

    /// Ids logged by `now`: Upper A Monday 07:xx, Run 1 Tuesday morning.
    private func done(at now: Date) -> Set<String> {
        var ids = Set<String>()
        if now >= f.day(7, hour: 9) { ids.insert("upper-a") }
        if now >= f.day(8, hour: 8) { ids.insert("run-1") }
        return ids
    }

    private func alarms(at now: Date) throws -> [PlannedAlarm] {
        AlarmSchedule.make(now: now, programme: try f.phase1(), profile: profile(), answers: { _ in answers },
                           completed: done(at: now), calendar: f.calendar)
    }

    private func day(_ n: Int, at now: Date) throws -> DayPlan {
        try #require(DayPlan.make(for: f.day(n), programme: try f.phase1(), profile: profile(),
                                  answers: { _ in answers }, now: now, completed: done(at: now),
                                  calendar: f.calendar))
    }

    private func weekday(_ date: Date) -> Weekday {
        Weekday(calendarWeekday: f.calendar.component(.weekday, from: date))
    }

    private func alarm(on n: Int, in list: [PlannedAlarm]) -> PlannedAlarm? {
        list.first { f.calendar.isDate($0.fireDate, inSameDayAs: f.day(n)) }
    }

    @Test func a2SundayEveningSetsTheWeeksAlarmsOnSessionAndOfficeDaysOnly() throws {
        let set = try alarms(at: f.day(6, hour: 18))
        #expect((7...14).contains(set.count), "\(set.count) alarms")
        let week2 = set.filter { $0.fireDate >= f.day(7) && $0.fireDate < f.day(14) }
        // E14: Mon, Tue, Thu (office and sessions) and Sat (Upper B). No Wednesday, Friday or Sunday walk.
        #expect(Set(week2.map { weekday($0.fireDate) }) == [.monday, .tuesday, .thursday, .saturday])
    }

    @Test func a3MondayShowsUpperAAtTheAlarmsTime() throws {
        let now = f.day(7, hour: 6)
        let monday = try day(7, at: now)
        #expect(monday.session?.id == "upper-a")
        #expect(monday.leave != nil) // office day
        let ringing = try #require(alarm(on: 7, in: try alarms(at: f.day(6, hour: 18))))
        let parts = f.calendar.dateComponents([.hour, .minute], from: ringing.fireDate)
        #expect(monday.alarm == TimeOfDay(hour: parts.hour!, minute: parts.minute!))
    }

    @Test func a7WednesdayIsRestWithNoAlarmAndWindsDownForThursday() throws {
        let wednesday = try day(9, at: f.day(9, hour: 12))
        #expect(wednesday.session == nil)
        #expect(wednesday.alarm == nil)
        let thursday = try day(10, at: f.day(9, hour: 12))
        let wake = try #require(thursday.alarm)
        let s = profile().schedule
        let sleep = Int(s.sleepHours * 60) + s.fallAsleepMinutes
        let expected = wake.adding(minutes: -sleep)
        // Lights out from Thursday's alarm, capped at the latest bedtime.
        let cap = s.latestBedtime
        let night = { (t: TimeOfDay) in t.hour < 12 ? t.minutesSinceMidnight + 1_440 : t.minutesSinceMidnight }
        #expect(wednesday.lightsOut == (night(expected) < night(cap) ? expected : cap))
    }

    @Test func a8ThursdaysMissedFullBodyMovesToFriday() throws {
        let now = f.day(10, hour: 21)
        let friday = try day(11, at: now)
        #expect(friday.session?.id == "full-body")
        #expect(friday.session?.movedFrom == .thursday)
        #expect(try day(10, at: now).session?.id != "full-body")
    }

    @Test func a9FridaysMovedSessionKeepsItsAlarm() throws {
        // QA-15: set at Thursday 21:00, still there at Friday 07:00.
        let thursdayNight = try #require(alarm(on: 11, in: try alarms(at: f.day(10, hour: 21))))
        #expect(thursdayNight.title.hasPrefix("Full body"))
        let fridayMorning = f.day(11, hour: 7)
        let friday = try day(11, at: fridayMorning)
        #expect(friday.session?.id == "full-body")
        #expect(friday.session?.start == TimeOfDay(hour: 8, minute: 5)) // Friday morning, not the evening
        #expect(friday.session?.movedFrom == .thursday)
        let parts = f.calendar.dateComponents([.hour, .minute], from: thursdayNight.fireDate)
        #expect(friday.alarm == TimeOfDay(hour: parts.hour!, minute: parts.minute!))
        // The alarm the reconcile keeps at Friday 07:00 is the same one, and matches Today.
        let ringing = try #require(alarm(on: 11, in: try alarms(at: fridayMorning)))
        #expect(ringing.fireDate == thursdayNight.fireDate)
        #expect(ringing.id == thursdayNight.id)
    }

    @Test func a10SaturdayIsUpperBAtTheDayOffTimeAndWindsDownLikeAWeekday() throws {
        let now = f.day(12, hour: 7)
        let saturday = try day(12, at: now)
        #expect(saturday.session?.id == "upper-b")
        #expect(saturday.session?.start == profile().schedule.dayOffSessionStart)
        // E14: no alarm Sunday, so Saturday's wind-down follows the week's median alarm,
        // staying within 30 minutes of the weeknight lights-out.
        let night = { (t: TimeOfDay) in t.hour < 12 ? t.minutesSinceMidnight + 1_440 : t.minutesSinceMidnight }
        let weeknights = try [7, 8, 9].map { night(try day($0, at: f.day(6, hour: 18)).lightsOut) }.sorted()
        #expect(abs(night(saturday.lightsOut) - weeknights[1]) <= 30, "\(saturday.lightsOut) vs \(weeknights)")
    }

    @Test func a11SundayWalkIsShownWithNoAlarm() throws {
        let sunday = try day(13, at: f.day(13, hour: 9))
        #expect(sunday.session?.id == "walk")
        #expect(sunday.alarm == nil)
        #expect(alarm(on: 13, in: try alarms(at: f.day(12, hour: 22))) == nil)
    }

    /// QA-15's real property: opening the app later never changes the plan by
    /// itself. Hourly from 05:00 to 23:00 across the week (and 23:00 to the next
    /// 05:00), two consecutive opens agree unless a slot ended or a log was
    /// added in between.
    @Test func thePlanOnlyChangesWhenASlotEndsOrALogIsAdded() throws {
        let p = try f.phase1()
        let times = (7...13).flatMap { d in (5...23).map { f.day(d, hour: $0) } }
        func plan(_ now: Date) -> WeekPlan {
            WeekPlanner.plan(weekStarting: f.day(7), programme: p, profile: profile(), answers: answers,
                             now: now, completed: done(at: now), calendar: f.calendar)
        }
        func end(_ day: WeekPlan.Day) -> Date? {
            day.session.flatMap { f.calendar.date(bySettingHour: $0.end.hour, minute: $0.end.minute, second: 0, of: day.date) }
        }
        var changes = 0
        for (earlier, later) in zip(times, times.dropFirst()) {
            let a = plan(earlier), b = plan(later)
            let logged = done(at: earlier) != done(at: later)
            let slotEnded = a.days.contains { day in end(day).map { $0 > earlier && $0 <= later } ?? false }
            if logged || slotEnded {
                if a != b { changes += 1 }
                continue
            }
            #expect(a == b, "plan changed between \(earlier) and \(later) with no slot ending and no new log")
        }
        // The week does change: Monday's slot passing, its log, and Thursday's missed full body.
        #expect(changes >= 2)
    }

    /// QA-18 (QA's spec): for each missed-session scenario, sweep `now` in
    /// 15-minute steps from the moment of the move to Sunday 23:59. The moved
    /// session's day and start hold until its slot ends, and the wake alarm
    /// for that day matches the plan.
    @Test(arguments: [
        ("A8: full body missed", ["upper-a": 9, "run-1": 8 + 24]),  // hours after Mon 00:00 when each is logged
        ("nothing logged", [:]),
        ("Tuesday's run missed", ["upper-a": 9, "full-body": 3 * 24 + 9]),
    ] as [(String, [String: Int])])
    func qa18MovedSessionHoldsUntilItsSlotEnds(_ scenario: String, _ loggedAfter: [String: Int]) throws {
        let p = try f.phase1()
        let monday = f.day(7)
        let sundayEnd = f.day(13, hour: 23).addingTimeInterval(59 * 60)
        func completed(_ now: Date) -> Set<String> {
            Set(loggedAfter.filter { now >= monday.addingTimeInterval(Double($0.value) * 3_600) }.keys)
        }
        func plan(_ now: Date) -> WeekPlan {
            WeekPlanner.plan(weekStarting: monday, programme: p, profile: profile(), answers: answers,
                             now: now, completed: completed(now), calendar: f.calendar)
        }
        func at(_ time: TimeOfDay, on date: Date) -> Date {
            f.calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: date)!
        }

        var tracked: [String: (day: Weekday, start: TimeOfDay, ends: Date)] = [:]
        var moves = 0
        var now = f.day(7, hour: 5)
        while now <= sundayEnd {
            let week = plan(now)
            for day in week.days {
                guard let placement = day.session, placement.movedFrom != nil else { continue }
                let id = placement.sessionID
                if let held = tracked[id], now < held.ends {
                    #expect(day.weekday == held.day && placement.start == held.start,
                            "\(scenario): \(id) moved from \(held.day) \(held.start) to \(day.weekday) \(placement.start) at \(now)")
                } else if tracked[id] == nil || now >= tracked[id]!.ends {
                    if tracked[id] == nil { moves += 1 }
                    tracked[id] = (day.weekday, placement.start, at(placement.end, on: day.date))
                }
            }
            // Every tracked move still ahead keeps its session and its alarm.
            let alarms = AlarmSchedule.make(now: now, programme: p, profile: profile(), answers: { _ in answers },
                                            completed: completed(now), calendar: f.calendar)
            for (id, held) in tracked where now < held.ends {
                let day = try #require(week.day(held.day))
                #expect(day.session?.sessionID == id, "\(scenario): \(id) gone from \(held.day) at \(now)")
                if let wake = day.wake, at(wake, on: day.date) > now {
                    let alarm = alarms.first { f.calendar.isDate($0.fireDate, inSameDayAs: day.date) }
                    #expect(alarm?.fireDate == at(wake, on: day.date),
                            "\(scenario): \(held.day) alarm \(String(describing: alarm?.fireDate)) vs plan \(wake) at \(now)")
                }
            }
            now = now.addingTimeInterval(15 * 60)
        }
        #expect(moves >= 1, "\(scenario): expected at least one move")
    }

    /// Regression (#56 UI run): onboarding later in the week than `now` (the
    /// week1-monday fixture opened on a real clock before its confirm date)
    /// must not trap, and replays only today.
    @Test func onboardingLaterThisWeekThanNowDoesNotTrap() throws {
        var later = profile()
        later.programme.confirmedOn = f.day(13, hour: 18) // Sunday of week 2
        let week = WeekPlanner.plan(weekStarting: f.day(7), programme: try f.phase1(), profile: later,
                                    answers: answers, now: f.day(8, hour: 12), calendar: f.calendar)
        #expect(week.day(.monday)?.session?.sessionID == "upper-a") // before onboarding: done on paper
        let alarms = AlarmSchedule.make(now: f.day(8, hour: 12), programme: try f.phase1(), profile: later,
                                        answers: { _ in answers }, calendar: f.calendar)
        #expect(!alarms.isEmpty)
    }
}
