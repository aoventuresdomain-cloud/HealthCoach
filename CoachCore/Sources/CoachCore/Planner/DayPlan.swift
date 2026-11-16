import Foundation

/// One day as Today shows it: the session, its time, and the sleep rule's
/// wake, wind-down and lights-out (design M1-03, board M1-05).
///
/// Interim placement until the M2 planner: the alarm is the profile's
/// earliest wake every day and a session starts 15 minutes after it. Only
/// `make` decides that, so the M2 planner can replace it behind the same call.
public struct DayPlan: Equatable, Sendable {
    public let planned: PlannedDay
    public let alarm: TimeOfDay
    public let session: SessionSlot?
    public let windDown: TimeOfDay
    public let lightsOut: TimeOfDay
    /// Wake, session or fixed event, wind-down; in time order (untimed fixed events last but one).
    public let timeline: [TimelineItem]

    public struct SessionSlot: Equatable, Sendable {
        /// Key into `Programme.sessions`.
        public let id: String
        public let name: String
        public let session: Session
        public let start: TimeOfDay
        /// Expected length for this week, warm-up included; nil when the data has none.
        public let minutes: Int?

        public var end: TimeOfDay? { minutes.map { start.adding(minutes: $0) } }
    }

    public struct TimelineItem: Equatable, Sendable, Identifiable {
        public enum Kind: String, Sendable { case wake, session, fixed, windDown }
        public let kind: Kind
        /// nil for a fixed event with only a part of day ("evening").
        public let time: TimeOfDay?
        public let title: String
        public let detail: String?
        public var id: String { kind.rawValue }
    }

    /// Minutes between the alarm and the session start (interim placement).
    public static let sessionOffsetMinutes = 15

    /// The plan for `date`, or nil until onboarding has set a start date.
    public static func make(for date: Date, programme: Programme, profile: Profile,
                            calendar: Calendar = .current) -> DayPlan? {
        guard let start = profile.programme.startDate else { return nil }
        let planned = programme.plannedDay(on: date, start: start, calendar: calendar)
        let schedule = profile.schedule
        let alarm = schedule.earliestWake
        // One sleep rule: lights out = alarm − sleep − time to fall asleep; wind-down before that.
        let asleepMinutes = Int((schedule.sleepHours * 60).rounded())
        let lightsOut = alarm.adding(minutes: -(asleepMinutes + schedule.fallAsleepMinutes))
        let windDown = lightsOut.adding(minutes: -schedule.windDownMinutes)

        var slot: SessionSlot?
        var timeline = [TimelineItem(kind: .wake, time: alarm, title: "Wake", detail: "Alarm")]
        switch planned.entry {
        case let .session(id, session):
            let start = alarm.adding(minutes: sessionOffsetMinutes)
            let made = SessionSlot(id: id, name: session.name, session: session, start: start,
                                   minutes: planned.week.flatMap { session.minutes(inWeek: $0) })
            slot = made
            timeline.append(TimelineItem(kind: .session, time: start, title: made.name,
                                         detail: made.end.map { "Done by \($0)" }))
        case let .fixed(event):
            timeline.append(TimelineItem(kind: .fixed, time: nil, title: event.name,
                                         detail: event.time.prefix(1).uppercased() + event.time.dropFirst()))
        case .rest, .beforeStart, .afterEnd:
            break
        }
        timeline.append(TimelineItem(kind: .windDown, time: windDown, title: "Wind down",
                                     detail: "Lights out \(lightsOut) for a \(alarm) alarm"))
        return DayPlan(planned: planned, alarm: alarm, session: slot, windDown: windDown,
                       lightsOut: lightsOut, timeline: timeline)
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
