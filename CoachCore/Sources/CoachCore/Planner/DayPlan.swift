import Foundation

/// One day as Today shows it: the session, its time, the leave time and the
/// sleep rule's wake, wind-down and lights-out (design M1-03, board M1-05).
///
/// Times come from the week planner (M2-01), the same plan the wake alarms
/// are built from (M2-02), so Today never shows a different alarm from the
/// one that rings (QA-9).
public struct DayPlan: Equatable, Sendable {
    public let planned: PlannedDay
    /// nil on a day off with nothing planned (no alarm: sleep in).
    public let alarm: TimeOfDay?
    public let session: SessionSlot?
    /// Leave for the office; nil on home days and days off.
    public let leave: TimeOfDay?
    /// Tonight, before tomorrow's alarm.
    public let windDown: TimeOfDay
    public let lightsOut: TimeOfDay
    /// Wake, session or fixed event and leave, then wind-down; in time order
    /// (untimed fixed events last but one).
    public let timeline: [TimelineItem]

    public struct SessionSlot: Equatable, Sendable {
        /// Key into `Programme.sessions`.
        public let id: String
        public let name: String
        public let session: Session
        public let start: TimeOfDay
        /// Planned length, warm-up included (the planner's slot).
        public let minutes: Int?
        /// Set when the planner moved the session here from its programme day.
        public let movedFrom: Weekday?

        public var end: TimeOfDay? { minutes.map { start.adding(minutes: $0) } }
    }

    public struct TimelineItem: Equatable, Sendable, Identifiable {
        public enum Kind: String, Sendable { case wake, session, fixed, leave, windDown }
        public let kind: Kind
        /// nil for a fixed event with only a part of day ("evening").
        public let time: TimeOfDay?
        public let title: String
        public let detail: String?
        public var id: String { kind.rawValue }
    }

    /// The plan for `date`, or nil until onboarding has set a start date.
    /// `answers` and `dropping` must be what the alarm reconcile used (the
    /// Sunday prompt's answers for the week starting a Monday, and the reduced
    /// week), so Today and the alarm agree. `now` and `completed` (session ids
    /// logged today) move a session whose time has passed (E13).
    public static func make(for date: Date, programme: Programme, profile: Profile,
                            answers: (Date) -> WeekAnswers = { _ in WeekAnswers() },
                            dropping: Set<String> = [],
                            now: Date? = nil, completed: Set<String> = [],
                            calendar: Calendar = .current) -> DayPlan? {
        guard let start = profile.programme.startDate else { return nil }
        let planned = programme.plannedDay(on: date, start: start, calendar: calendar)
        let schedule = profile.schedule

        func plannerDay(_ date: Date) -> WeekPlan.Day? {
            let monday = AlarmSchedule.mondayOf(date, calendar: calendar)
            return WeekPlanner.plan(weekStarting: monday, programme: programme, profile: profile,
                                    answers: answers(monday), dropping: dropping,
                                    now: now, completed: completed, calendar: calendar)
                .days.first { calendar.isDate($0.date, inSameDayAs: date) }
        }
        let today = plannerDay(date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date).flatMap(plannerDay)

        // One sleep rule, from tomorrow's alarm; with no alarm tomorrow, the latest bedtime.
        let lightsOut = tomorrow?.lightsOutBefore ?? schedule.latestBedtime
        let windDown = lightsOut.adding(minutes: -schedule.windDownMinutes)

        var slot: SessionSlot?
        var timeline: [TimelineItem] = []
        if let wake = today?.wake {
            timeline.append(TimelineItem(kind: .wake, time: wake, title: "Wake", detail: "Alarm"))
        }
        if let placement = today?.session, let session = programme.sessions[placement.sessionID] {
            let minutes = placement.end.minutesSinceMidnight - placement.start.minutesSinceMidnight
            let made = SessionSlot(id: placement.sessionID, name: session.name, session: session,
                                   start: placement.start, minutes: minutes, movedFrom: placement.movedFrom)
            slot = made
            timeline.append(TimelineItem(kind: .session, time: made.start, title: made.name,
                                         detail: made.end.map { "Done by \($0)" }))
        }
        if let leave = today?.leave {
            timeline.append(TimelineItem(kind: .leave, time: leave, title: "Leave for the office",
                                         detail: "\(schedule.commuteMinutes) min"))
        }
        timeline.sort { ($0.time?.minutesSinceMidnight ?? .max) < ($1.time?.minutesSinceMidnight ?? .max) }
        if let event = today?.fixed {
            timeline.append(TimelineItem(kind: .fixed, time: nil, title: event.name,
                                         detail: event.time.prefix(1).uppercased() + event.time.dropFirst()))
        }
        let windDownDetail = tomorrow?.wake.map { "Lights out \(lightsOut) for a \($0) alarm" }
            ?? "Lights out \(lightsOut), no alarm tomorrow"
        timeline.append(TimelineItem(kind: .windDown, time: windDown, title: "Wind down", detail: windDownDetail))
        return DayPlan(planned: planned, alarm: today?.wake, session: slot, leave: today?.leave,
                       windDown: windDown, lightsOut: lightsOut, timeline: timeline)
    }
}

extension Session {
    /// Expected length in `week` (1-based), warm-up included, from the data.
    public func minutes(inWeek week: Int) -> Int? {
        switch self {
        case let .strength(s): s.durationMinutes[safe: week - 1]
        case let .walk(s): s.durationMinutes[safe: week - 1]
        case let .runWalk(s): s.weeks.first { $0.week == week }?.durationMinutes
        case .circuit: nil
        }
    }
}

extension TimeOfDay {
    /// Wraps round midnight in either direction.
    public func adding(minutes: Int) -> TimeOfDay {
        let total = ((minutesSinceMidnight + minutes) % 1440 + 1440) % 1440
        return TimeOfDay(hour: total / 60, minute: total % 60)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Programme {
    /// Week 1 starts on the Monday on or after the day onboarding is confirmed,
    /// so a programme week always runs Monday to Sunday.
    public static func startDate(confirmedOn date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: day))
        let daysToMonday = (7 - Weekday.allCases.firstIndex(of: weekday)!) % 7
        return calendar.date(byAdding: .day, value: daysToMonday, to: day) ?? day
    }
}
