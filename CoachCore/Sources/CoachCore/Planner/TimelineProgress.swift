import Foundation

extension DayPlan {
    /// QA-28: where Today's timeline stands at `now`. Returns the index of the
    /// current row, the first row that isn't over yet; every row before it is
    /// past. Returns `timeline.count` when the whole day is over.
    ///
    /// A row is over once its end has passed: the session's end (`Done by`),
    /// lights out for wind-down, and the time itself for wake and leave. An
    /// untimed fixed event ("Basketball, evening") is over once a later timed
    /// row has started. This works whatever rows the day has, so a day whose
    /// session moved away (A8) still lands on wind-down, not on the morning's
    /// leave time.
    public func timelineProgress(at now: TimeOfDay) -> Int {
        let timedOver: [Bool?] = timeline.map { item in
            guard let time = item.time else { return nil }
            switch item.kind {
            case .session: return (session?.end ?? time) <= now
            case .windDown: return (lightsOut > time ? lightsOut : time) <= now
            case .wake, .leave, .fixed, .lunch: return time < now
            }
        }
        let over = timeline.indices.map { index in
            timedOver[index] ?? timeline[(index + 1)...].contains { $0.time.map { $0 <= now } ?? false }
        }
        return over.firstIndex(of: false) ?? timeline.count
    }
}
