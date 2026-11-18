import Foundation

/// The Sunday prompt's answers for one week (plan §4.1, decision D5): which
/// days are in the office, plus any early starts or late finishes.
public struct WeekAnswers: Codable, Sendable, Equatable {
    public var officeDays: Set<Weekday>
    /// First commitment earlier than `workStart` (an 08:00 meeting).
    public var earlyStarts: [Weekday: TimeOfDay]
    /// Work ends later than `workEnd`.
    public var lateFinishes: [Weekday: TimeOfDay]

    public init(officeDays: Set<Weekday> = [], earlyStarts: [Weekday: TimeOfDay] = [:],
                lateFinishes: [Weekday: TimeOfDay] = [:]) {
        self.officeDays = officeDays
        self.earlyStarts = earlyStarts
        self.lateFinishes = lateFinishes
    }
}

/// One planned week: what happens each day and when (board M2-01).
public struct WeekPlan: Sendable, Equatable {
    /// Monday to Sunday.
    public let days: [Day]
    /// Sessions that fit no slot on any allowed day this week.
    public let unplaced: [Unplaced]

    public struct Day: Sendable, Equatable {
        public let date: Date
        public let weekday: Weekday
        /// Programme week, nil outside the programme.
        public let week: Int?
        public let kind: Kind
        public let session: Placement?
        public let fixed: Programme.FixedEvent?
        /// The alarm; nil on a day off with nothing planned (no alarm, sleep in).
        public let wake: TimeOfDay?
        /// Leave for the office; nil on home days and days off.
        public let leave: TimeOfDay?
        /// Lights out the night before, from this day's alarm and the sleep rule;
        /// on a day with no alarm, from the week's median alarm (E14).
        public let lightsOutBefore: TimeOfDay?
    }

    public enum Kind: String, Sendable, Equatable { case office, home, dayOff }

    public enum Slot: String, Sendable, Equatable { case morning, evening }

    public struct Placement: Sendable, Equatable {
        /// Key into `Programme.sessions`.
        public let sessionID: String
        public let slot: Slot
        public let start: TimeOfDay
        public let end: TimeOfDay
        /// Set when the programme's day had no room and the session moved here.
        public let movedFrom: Weekday?
    }

    public struct Unplaced: Sendable, Equatable {
        public let sessionID: String
        public let scheduledOn: Weekday
    }

    public func day(_ weekday: Weekday) -> Day? { days.first { $0.weekday == weekday } }

    /// C3: the days that train, for the meal plan: a strength or run session,
    /// or a fixed event such as basketball. A walk doesn't count.
    public func trainingDays(programme: Programme) -> Set<Weekday> {
        Set(days.filter { day in
            if day.fixed != nil { return true }
            guard let id = day.session?.sessionID, let session = programme.sessions[id] else { return false }
            if case .walk = session { return false }
            return true
        }.map(\.weekday))
    }
}

/// Places the week's sessions in the morning or evening slot around work,
/// the commute and basketball, and works out each alarm (board M2-01).
///
/// Wake = first commitment − commute − shower − session − buffer (plan §4.1),
/// never before `earliestWake`. Lights out = wake − sleep − fall-asleep, never
/// after `latestBedtime`. Morning first; evening when the morning won't fit; a
/// session that fits neither moves to the nearest free day the programme's
/// placement rules allow. `dropping` leaves sessions out (the reduced week,
/// `Programme.droppedSessions(history:)`).
///
/// With `now` in this week, every session on an earlier day since onboarding
/// (`programme.confirmedOn`; earlier days were on paper), and today's once
/// its slot has ended, that isn't in `completed` (this week's logged session
/// ids, whatever day they were logged) moves (decision E13): to this evening's
/// normal slot if it ends at least 2 h before wind-down, else to the next
/// session-free legal day this week, else it is dropped quietly (listed in
/// `unplaced`, no copy for the owner). Never two sessions in a day, never into
/// next week.
public enum WeekPlanner {
    /// Session start times are rounded down to this many minutes.
    public static let roundingMinutes = 5
    /// Length used when the data has none (circuits).
    public static let fallbackSessionMinutes = 30

    public static func plan(weekStarting monday: Date, programme: Programme, profile: Profile,
                            answers: WeekAnswers, dropping: Set<String> = [],
                            now: Date? = nil, completed: Set<String> = [],
                            calendar: Calendar = .current) -> WeekPlan {
        guard let start = profile.programme.startDate else {
            return WeekPlan(days: [], unplaced: [])
        }
        let s = profile.schedule
        let dates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: monday)) }
        let planned = dates.map { programme.plannedDay(on: $0, start: start, calendar: calendar) }

        func kind(_ day: Weekday) -> WeekPlan.Kind {
            if day == .saturday || day == .sunday { return .dayOff }
            return answers.officeDays.contains(day) ? .office : .home
        }

        func minutes(_ id: String, week: Int?) -> Int {
            guard let session = programme.sessions[id], let week else { return fallbackSessionMinutes }
            return session.plannedMinutes(week: week) ?? fallbackSessionMinutes
        }

        /// The slot `id` would take on `day`, or nil if neither window fits.
        func fit(_ id: String, week: Int?, on day: Weekday) -> (WeekPlan.Slot, start: Int, end: Int)? {
            let length = minutes(id, week: week)
            let k = kind(day)
            let allowsMorning = s.trainingWindows != .evening
            let allowsEvening = s.trainingWindows != .morning
            if k == .dayOff {
                let begin = s.dayOffSessionStart.minutesSinceMidnight
                return (.morning, begin, begin + length)
            }
            let travel = k == .office ? s.commuteMinutes : 0
            if allowsMorning {
                let first = (answers.earlyStarts[day] ?? s.workStart).minutesSinceMidnight
                let begin = roundDown(first - travel - s.showerMinutes - length)
                if begin - s.wakeBufferMinutes >= s.earliestWake.minutesSinceMidnight {
                    return (.morning, begin, begin + length)
                }
            }
            if allowsEvening {
                let finish = (answers.lateFinishes[day] ?? s.workEnd).minutesSinceMidnight
                let begin = roundUp(finish + travel)
                if begin + length + s.showerMinutes <= s.eveningEndBy.minutesSinceMidnight {
                    return (.evening, begin, begin + length)
                }
            }
            return nil
        }

        // Day → placement; filled in programme order, moving what doesn't fit.
        var placements: [Weekday: WeekPlan.Placement] = [:]
        var unplaced: [WeekPlan.Unplaced] = []
        var fixedDays = Set<Weekday>()
        var sessionDays = Set<Weekday>()
        for day in planned {
            switch day.entry {
            case .fixed: fixedDays.insert(day.weekday)
            case let .session(id, _): if !dropping.contains(id) { sessionDays.insert(day.weekday) }
            case .rest, .beforeStart, .afterEnd: break
            }
        }

        /// True when `event` (a fixed event id) falls on the day after `day`.
        func isDayBefore(_ event: String, _ day: Weekday) -> Bool {
            planned.contains { other in
                guard case let .fixed(e) = other.entry else { return false }
                return e.id == event && other.weekday.previous == day
            }
        }

        func allowed(_ id: String, on day: Weekday) -> Bool {
            if programme.placementRules.neverOn.contains(day) { return false }
            if fixedDays.contains(day) { return false }
            for (event, banned) in programme.placementRules.notTheDayBefore
            where banned.contains(id) && isDayBefore(event, day) {
                return false
            }
            return true
        }

        for day in planned {
            guard case let .session(id, _) = day.entry, !dropping.contains(id) else { continue }
            if let slot = fit(id, week: day.week, on: day.weekday) {
                placements[day.weekday] = .init(sessionID: id, slot: slot.0, start: time(slot.start),
                                                end: time(slot.end), movedFrom: nil)
                continue
            }
            // Nearest free day: later first, then earlier, within the week.
            let order = Weekday.allCases.sorted {
                let a = distance(from: day.weekday, to: $0), b = distance(from: day.weekday, to: $1)
                return a != b ? a < b : $0 > $1
            }
            let target = order.first { other in
                other != day.weekday && !sessionDays.contains(other) && placements[other] == nil
                    && allowed(id, on: other) && fit(id, week: day.week, on: other) != nil
            }
            if let target, let slot = fit(id, week: day.week, on: target) {
                placements[target] = .init(sessionID: id, slot: slot.0, start: time(slot.start),
                                           end: time(slot.end), movedFrom: day.weekday)
            } else {
                unplaced.append(.init(sessionID: id, scheduledOn: day.weekday))
            }
        }

        func buildDays() -> [WeekPlan.Day] {
        var days: [WeekPlan.Day] = []
        for (date, day) in zip(dates, planned) {
            let k = kind(day.weekday)
            let placement = placements[day.weekday]
            var fixed: Programme.FixedEvent?
            if case let .fixed(e) = day.entry { fixed = e }
            // Decision E14 (refines E11, QA-11): an alarm only on a day with a fixed
            // start, a session that sets an alarm or an office day. Home rest days,
            // a home Wednesday and a day whose only plan is optional (the Sunday
            // walk) have no alarm.
            let setsAlarm = placement.flatMap { programme.sessions[$0.sessionID] }?.setsAlarm ?? false
            var wake: Int?
            if !setsAlarm && k != .office {
                wake = nil
            } else if let placement, placement.slot == .morning {
                wake = placement.start.minutesSinceMidnight - s.wakeBufferMinutes
            } else if k != .dayOff {
                let first = (answers.earlyStarts[day.weekday] ?? s.workStart).minutesSinceMidnight
                let travel = k == .office ? s.commuteMinutes : 0
                wake = max(roundDown(first - travel - s.showerMinutes - s.wakeBufferMinutes),
                           s.earliestWake.minutesSinceMidnight)
            }
            let leave: TimeOfDay? = k == .office
                ? time((answers.earlyStarts[day.weekday] ?? s.workStart).minutesSinceMidnight - s.commuteMinutes)
                : nil
            let lightsOut: TimeOfDay? = wake.map { Self.lightsOut(forWake: $0, schedule: s) }
            days.append(.init(date: date, weekday: day.weekday, week: day.week, kind: k,
                              session: placement, fixed: fixed, wake: wake.map(time),
                              leave: leave, lightsOutBefore: lightsOut))
        }
        return withFreeDayLightsOut(days, schedule: s)
        }

        var days = buildDays()

        // E13, replayed over the week (QA-15, QA-18): stateless, so a move made
        // yesterday is made again today. Each unlogged session passes when its
        // slot ends; passes are replayed one at a time, in the order they
        // happened, each decided as at that moment: this evening if it still
        // fits, else the next free legal day, else dropped quietly. A moved
        // session holds until its new slot ends, so opening the app later never
        // changes the plan by itself. Never before the day it passed, never two
        // in a day, never into next week. Days before onboarding were trained
        // on paper and count as done.
        if let now, let todayIndex = dates.firstIndex(where: { calendar.isDate($0, inSameDayAs: now) }) {
            let parts = calendar.dateComponents([.hour, .minute], from: now)
            let nowMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            let firstReplayed = profile.programme.confirmedOn.map { confirmed in
                dates.firstIndex { $0 >= calendar.startOfDay(for: confirmed) } ?? dates.count
            } ?? todayIndex

            /// Start of the evening slot on day `index` for a session that passed
            /// at `passedAt`, if the day is free and the slot still works. The
            /// slot is the normal evening start (end of the work day, or `workEnd`
            /// on a day off), never the clock (QA-16).
            func evening(_ id: String, length: Int, on index: Int, passedAt: Int) -> Int? {
                let day = planned[index].weekday
                guard placements[day] == nil, allowed(id, on: day) else { return nil }
                let k = kind(day)
                let finish = k == .dayOff ? s.workEnd.minutesSinceMidnight
                    : (answers.lateFinishes[day] ?? s.workEnd).minutesSinceMidnight + (k == .office ? s.commuteMinutes : 0)
                let begin = roundUp(finish)
                guard passedAt < begin + length else { return nil }
                // That night's wind-down, from the next day's alarm (or the latest bedtime).
                let next = index + 1 < days.count ? days[index + 1].lightsOutBefore : nil
                var windDown = (next ?? s.latestBedtime).minutesSinceMidnight - s.windDownMinutes
                if windDown < 12 * 60 { windDown += 1440 }
                guard begin + length <= windDown - Self.passedSessionMarginMinutes, begin + length < 1440 else { return nil }
                return begin
            }

            /// The next unlogged session to pass by `now`: earliest day, then earliest end.
            func nextPass() -> (index: Int, placement: WeekPlan.Placement)? {
                // Today always replays; earlier days only from onboarding on. (A
                // `firstReplayed...todayIndex` range would trap when onboarding is
                // later this week than today, as in the week1-monday fixture.)
                for index in 0...todayIndex where index == todayIndex || index >= firstReplayed {
                    let weekday = planned[index].weekday
                    guard let placement = placements[weekday], !completed.contains(placement.sessionID) else { continue }
                    if index < todayIndex || placement.end.minutesSinceMidnight <= nowMinutes {
                        return (index, placement)
                    }
                }
                return nil
            }

            var moved = false
            // Each pass moves a session to a later slot or drops it, so this ends;
            // the bound is a guard against a future rule that doesn't.
            for _ in 0..<(7 * 4) {
                guard let (index, placement) = nextPass() else { break }
                moved = true
                let weekday = planned[index].weekday
                placements[weekday] = nil
                let id = placement.sessionID
                let from = placement.movedFrom ?? weekday
                let week = planned.first { day in
                    if case let .session(sid, _) = day.entry { return sid == id && day.weekday == from }
                    return false
                }?.week ?? planned[index].week
                let length = minutes(id, week: week)
                if let begin = evening(id, length: length, on: index, passedAt: placement.end.minutesSinceMidnight) {
                    placements[weekday] = .init(sessionID: id, slot: .evening, start: time(begin),
                                                end: time(begin + length), movedFrom: nil)
                } else if let target = planned[(index + 1)...].first(where: { day in
                    placements[day.weekday] == nil && !sessionDays.contains(day.weekday)
                        && allowed(id, on: day.weekday) && fit(id, week: week, on: day.weekday) != nil
                }), let slot = fit(id, week: week, on: target.weekday) {
                    placements[target.weekday] = .init(sessionID: id, slot: slot.0, start: time(slot.start),
                                                       end: time(slot.end), movedFrom: from)
                } else {
                    unplaced.append(.init(sessionID: id, scheduledOn: from))
                }
            }
            if moved { days = buildDays() }
        }
        return WeekPlan(days: days, unplaced: unplaced)
    }

    /// E13: a passed session moves to this evening only if it ends this long before wind-down.
    public static let passedSessionMarginMinutes = 120

    /// E14: the night before a day with no alarm, lights out comes from the
    /// week's median alarm, so bedtime stays close to the other nights.
    private static func withFreeDayLightsOut(_ days: [WeekPlan.Day], schedule s: Profile.Schedule) -> [WeekPlan.Day] {
        let wakes = days.compactMap(\.wake).map(\.minutesSinceMidnight).sorted()
        guard !wakes.isEmpty else { return days }
        let median = wakes.count % 2 == 1
            ? wakes[wakes.count / 2]
            : roundDown((wakes[wakes.count / 2 - 1] + wakes[wakes.count / 2]) / 2)
        let lightsOut = Self.lightsOut(forWake: median, schedule: s)
        return days.map { day in
            guard day.wake == nil else { return day }
            return WeekPlan.Day(date: day.date, weekday: day.weekday, week: day.week, kind: day.kind,
                                session: day.session, fixed: day.fixed, wake: nil, leave: day.leave,
                                lightsOutBefore: lightsOut)
        }
    }

    /// The sleep rule: wake − sleep − fall asleep, never later than the latest bedtime.
    static func lightsOut(forWake w: Int, schedule s: Profile.Schedule) -> TimeOfDay {
        let asleep = Int((s.sleepHours * 60).rounded()) + s.fallAsleepMinutes
        // Minutes after the previous midnight; never later than latestBedtime.
        let byRule = w - asleep + 1440
        var latest = s.latestBedtime.minutesSinceMidnight
        if latest < 12 * 60 { latest += 1440 }
        return time(min(byRule, latest))
    }

    // MARK: - Minutes

    private static func roundDown(_ m: Int) -> Int { Int((Double(m) / Double(roundingMinutes)).rounded(.down)) * roundingMinutes }
    private static func roundUp(_ m: Int) -> Int { Int((Double(m) / Double(roundingMinutes)).rounded(.up)) * roundingMinutes }

    private static func time(_ m: Int) -> TimeOfDay {
        let t = ((m % 1440) + 1440) % 1440
        return TimeOfDay(hour: t / 60, minute: t % 60)
    }

    /// Days from `a` forward to `b` within Monday–Sunday, as a closeness score:
    /// the same distance either way, so ties go to the later day.
    private static func distance(from a: Weekday, to b: Weekday) -> Int {
        let all = Weekday.allCases
        return abs(all.firstIndex(of: a)! - all.firstIndex(of: b)!)
    }
}

extension Weekday {
    /// The day before, within Monday–Sunday (nil for Monday).
    var previous: Weekday? {
        let all = Weekday.allCases
        let i = all.firstIndex(of: self)!
        return i > 0 ? all[i - 1] : nil
    }

}

extension Session {
    /// Expected length in `week`, warm-up included, from the programme data.
    /// False for an optional session or one the data says gets no alarm
    /// (decision E11): it never sets or moves an alarm.
    public var setsAlarm: Bool {
        if case let .walk(w) = self { return w.alarm && !w.optional }
        return true
    }

    func plannedMinutes(week: Int) -> Int? {
        switch self {
        case let .strength(s): week >= 1 && week <= s.durationMinutes.count ? s.durationMinutes[week - 1] : nil
        case let .walk(s): week >= 1 && week <= s.durationMinutes.count ? s.durationMinutes[week - 1] : nil
        case let .runWalk(s): s.weeks.first { $0.week == week }?.durationMinutes
        case .circuit: nil
        }
    }
}
