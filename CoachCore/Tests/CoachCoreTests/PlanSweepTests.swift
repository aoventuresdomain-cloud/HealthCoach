import Foundation
import Testing
@testable import CoachCore

/// QA-9 (M1 QA report): every one of the 42 days of Phase 1 gives a sane
/// Today, for several kinds of week, and Today agrees with the alarm.
@Suite struct PlanSweepTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    private var start: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 23))! }

    private func profile(_ edit: (inout Profile) -> Void = { _ in }) -> Profile {
        var p = Profile()
        p.confirmed = true
        p.programme.startDate = start
        edit(&p)
        return p
    }

    private static func t(_ h: Int, _ m: Int) -> TimeOfDay { TimeOfDay(hour: h, minute: m) }

    /// Kinds of week the Sunday prompt can produce.
    private static let weeks: [(name: String, answers: WeekAnswers)] = [
        ("all home", WeekAnswers()),
        ("all office", WeekAnswers(officeDays: [.monday, .tuesday, .wednesday, .thursday, .friday])),
        ("hybrid, early Tue, late Thu", WeekAnswers(officeDays: [.monday, .tuesday, .thursday],
                                                    earlyStarts: [.tuesday: t(8, 0)],
                                                    lateFinishes: [.thursday: t(19, 0)])),
        ("very early starts", WeekAnswers(officeDays: [.monday, .thursday],
                                          earlyStarts: [.monday: t(7, 0), .thursday: t(7, 0)])),
    ]

    /// Evening times past midnight sort after 23:59.
    private func night(_ time: TimeOfDay) -> Int {
        time.hour < 12 ? time.minutesSinceMidnight + 1440 : time.minutesSinceMidnight
    }

    @Test(arguments: [false, true])
    func everyDayOfPhaseOneIsSane(eveningOnly: Bool) throws {
        let programme = try phase1()
        let profile = profile { if eveningOnly { $0.schedule.trainingWindows = .evening } }
        let s = profile.schedule
        for (name, answers) in Self.weeks {
            for offset in 0..<42 {
                let date = try #require(calendar.date(byAdding: .day, value: offset, to: start))
                let label = "\(name)\(eveningOnly ? ", evening only" : ""), day \(offset + 1)"
                let plan = try #require(DayPlan.make(for: date, programme: programme, profile: profile,
                                                     answers: { _ in answers }, calendar: calendar), "\(label)")
                #expect(plan.planned.week == offset / 7 + 1, "\(label)")
                let weekday = plan.planned.weekday
                let workDay = weekday != .saturday && weekday != .sunday

                // Wake: always on a work day, never before the earliest wake.
                if workDay { #expect(plan.alarm != nil, "\(label): no alarm on a work day") }
                if let alarm = plan.alarm { #expect(alarm >= s.earliestWake, "\(label): alarm \(alarm)") }

                // The session: a real slot, never on Wednesday, within the limits.
                if let slot = plan.session {
                    let minutes = try #require(slot.minutes)
                    let end = try #require(slot.end)
                    #expect(minutes > 0 && minutes <= programme.maxSessionMinutes, "\(label): \(minutes) min")
                    #expect(slot.start < end, "\(label): ends before it starts")
                    #expect(!programme.placementRules.neverOn.contains(weekday), "\(label): \(slot.id) on \(weekday)")
                    if let alarm = plan.alarm, slot.start < Self.t(12, 0) {
                        #expect(alarm.minutesSinceMidnight + s.wakeBufferMinutes <= slot.start.minutesSinceMidnight,
                                "\(label): alarm \(alarm) too close to \(slot.start)")
                    }
                    if slot.start >= Self.t(12, 0) {
                        #expect(end.minutesSinceMidnight + s.showerMinutes <= s.eveningEndBy.minutesSinceMidnight,
                                "\(label): evening session ends \(end)")
                    }
                    if eveningOnly, workDay { #expect(slot.start >= Self.t(12, 0), "\(label): morning session") }
                    // Not the day before basketball if the programme says so.
                    let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: date))
                    if case let .fixed(event) = programme.plannedDay(on: tomorrow, start: start, calendar: calendar).entry {
                        #expect(!(programme.placementRules.notTheDayBefore[event.id] ?? []).contains(slot.id),
                                "\(label): \(slot.id) the day before \(event.id)")
                    }
                }

                // Sleep: lights out by the latest bedtime, wind-down before it.
                #expect(night(plan.lightsOut) <= night(s.latestBedtime), "\(label): lights out \(plan.lightsOut)")
                #expect(night(plan.windDown) < night(plan.lightsOut), "\(label)")

                // Timeline: timed items in order, wind-down last.
                let times = plan.timeline.compactMap(\.time).dropLast().map(\.minutesSinceMidnight)
                #expect(times == times.sorted(), "\(label): timeline out of order")
                #expect(plan.timeline.last?.kind == .windDown, "\(label)")

                // Today's alarm is the one AlarmSchedule registers.
                let monday = AlarmSchedule.mondayOf(date, calendar: calendar)
                let day = try #require(WeekPlanner.plan(weekStarting: monday, programme: programme, profile: profile,
                                                        answers: answers, calendar: calendar).day(weekday))
                let alarm = AlarmSchedule.alarm(for: day, programme: programme, calendar: calendar)
                let rings = alarm.map { calendar.dateComponents([.hour, .minute], from: $0.fireDate) }
                #expect(rings.map { Self.t($0.hour!, $0.minute!) } == plan.alarm, "\(label): Today and alarm differ")
            }
        }
    }

    @Test func everyScheduledSessionIsPlacedOnceOrListedUnplaced() throws {
        let programme = try phase1()
        for (name, answers) in Self.weeks {
            for week in 1...6 {
                let monday = try #require(calendar.date(byAdding: .day, value: 7 * (week - 1), to: start))
                let plan = WeekPlanner.plan(weekStarting: monday, programme: programme, profile: profile(),
                                            answers: answers, calendar: calendar)
                let scheduled = try #require(programme.schedule.first { $0.week == week }).days.values
                    .compactMap { $0 }.filter { programme.sessions[$0] != nil }.sorted()
                let placed = plan.days.compactMap(\.session?.sessionID)
                let accounted = (placed + plan.unplaced.map(\.sessionID)).sorted()
                #expect(accounted == scheduled, "\(name), week \(week)")
                #expect(Set(placed).count == placed.count, "\(name), week \(week): a session twice")
            }
        }
        // A normal week (all home) places everything.
        let plan = WeekPlanner.plan(weekStarting: start, programme: programme, profile: profile(),
                                    answers: WeekAnswers(), calendar: calendar)
        #expect(plan.unplaced.isEmpty)
    }
}
