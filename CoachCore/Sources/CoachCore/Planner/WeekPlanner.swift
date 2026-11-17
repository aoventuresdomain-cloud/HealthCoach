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
/// With `now` in this week, a session of today's whose slot has ended and
/// isn't in `completed` moves (decision E13): to this evening if it ends at
/// least 2 h before wind-down, else to the next session-free legal day this
/// week, else it is dropped quietly (listed in `unplaced`, no copy for the
/// owner). Never two sessions in a day, never into next week.
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

        // E13: today's session whose time has passed.
        if let now, let index = dates.firstIndex(where: { calendar.isDate($0, inSameDayAs: now) }),
           let passed = placements[planned[index].weekday], !completed.contains(passed.sessionID) {
            let today = planned[index].weekday
            let parts = calendar.dateComponents([.hour, .minute], from: now)
            let nowMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            // "Passed" means the whole slot is over, so opening the app just after
            // the alarm (or mid-session) never moves the session under the owner.
            if passed.end.minutesSinceMidnight <= nowMinutes {
                placements[today] = nil
                let week = planned[index].week
                let length = minutes(passed.sessionID, week: week)
                // Tonight's wind-down, from tomorrow's alarm (or the latest bedtime).
                let lightsOut = (index + 1 < days.count ? days[index + 1].lightsOutBefore : nil) ?? s.latestBedtime
                var windDown = lightsOut.minutesSinceMidnight - s.windDownMinutes
                if windDown < 12 * 60 { windDown += 1440 }
                let k = kind(today)
                let finish = k == .dayOff ? 0
                    : (answers.lateFinishes[today] ?? s.workEnd).minutesSinceMidnight + (k == .office ? s.commuteMinutes : 0)
                let begin = roundUp(max(finish, nowMinutes))
                if begin + length <= windDown - Self.passedSessionMarginMinutes, begin + length < 1440 {
                    placements[today] = .init(sessionID: passed.sessionID, slot: .evening, start: time(begin),
                                              end: time(begin + length), movedFrom: nil)
                } else if let target = planned[(index + 1)...].first(where: { day in
                    placements[day.weekday] == nil && !sessionDays.contains(day.weekday)
                        && allowed(passed.sessionID, on: day.weekday)
                        && fit(passed.sessionID, week: week, on: day.weekday) != nil
                }), let slot = fit(passed.sessionID, week: week, on: target.weekday) {
                    placements[target.weekday] = .init(sessionID: passed.sessionID, slot: slot.0,
                                                       start: time(slot.start), end: time(slot.end),
                                                       movedFrom: passed.movedFrom ?? today)
                } else {
                    unplaced.append(.init(sessionID: passed.sessionID, scheduledOn: passed.movedFrom ?? today))
                }
                days = buildDays()
            }
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
