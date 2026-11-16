import Foundation

/// What the programme has on one calendar date.
public struct PlannedDay: Equatable, Sendable {
    /// Programme week, 1-based. nil before the start date or after the last week.
    public let week: Int?
    public let weekday: Weekday
    public let entry: Entry

    public enum Entry: Equatable, Sendable {
        case session(id: String, Session)
        case fixed(Programme.FixedEvent)
        case rest
        case beforeStart
        case afterEnd
    }
}

extension Programme {
    /// The plan for `date`, counting 7-day weeks from `start` (the Monday of
    /// week 1, `Profile.programme.startDate`), in the owner's calendar.
    public func plannedDay(on date: Date, start: Date, calendar: Calendar = .current) -> PlannedDay {
        let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: date))
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
        guard days >= 0 else { return PlannedDay(week: nil, weekday: weekday, entry: .beforeStart) }
        let week = days / 7 + 1
        guard week <= weeks, let scheduled = schedule.first(where: { $0.week == week }) else {
            return PlannedDay(week: nil, weekday: weekday, entry: .afterEnd)
        }
        guard let id = scheduled.days[weekday] ?? nil else {
            return PlannedDay(week: week, weekday: weekday, entry: .rest)
        }
        if let session = sessions[id] {
            return PlannedDay(week: week, weekday: weekday, entry: .session(id: id, session))
        }
        if let event = fixed.first(where: { $0.id == id }) {
            return PlannedDay(week: week, weekday: weekday, entry: .fixed(event))
        }
        // Unknown ids are caught by validation; treat as rest rather than crash.
        return PlannedDay(week: week, weekday: weekday, entry: .rest)
    }
}
