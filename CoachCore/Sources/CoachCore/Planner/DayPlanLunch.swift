import Foundation

/// N9a (ease budget D8): the office lunch order as a row on Today's timeline,
/// so the order is seen with 0 taps. Office days only: the row comes from the
/// day's planned lunch, which `MealPlan.week` makes an office order only on an
/// office day and only from the orders within the owner's walk (N4) and not
/// disliked (N3). Today and Meals then always name the same order.
extension DayPlan {
    /// When the lunch row sits on the timeline.
    public static let officeLunchTime = TimeOfDay(hour: 12, minute: 30)

    /// This plan with "12:30 Lunch · <order>, <place>" added in time order
    /// when `meals` (the same day's meals) has an office lunch; unchanged on a
    /// home day, a day off, or when the order isn't in `orders`.
    public func withOfficeLunch(_ meals: MealDay?, orders: [LunchOrder],
                                at time: TimeOfDay = DayPlan.officeLunchTime) -> DayPlan {
        guard !timeline.contains(where: { $0.kind == .lunch }),
              let order = OfficeLunch.planned(meals, orders: orders) else { return self }
        let row = TimelineItem(kind: .lunch, time: time, title: "Lunch", detail: "\(order.order), \(order.place)")
        // Before the first later timed row; untimed fixed events stay last but one.
        var rows = timeline
        let index = rows.firstIndex { item in
            item.time.map { $0.minutesSinceMidnight > time.minutesSinceMidnight } ?? true
        } ?? rows.count
        rows.insert(row, at: index)
        return DayPlan(planned: planned, alarm: alarm, session: session, leave: leave,
                       windDown: windDown, lightsOut: lightsOut, timeline: rows)
    }
}

/// N9a and N4: what the lunch card shows when the Today row is tapped.
public enum OfficeLunch {
    /// The day's planned office order; nil on a non-office day.
    public static func planned(_ meals: MealDay?, orders: [LunchOrder]) -> LunchOrder? {
        guard let id = meals?.meals.first(where: { $0.slot == .lunch && $0.isOfficeLunch })?.lunchOrderID
        else { return nil }
        return orders.first { $0.id == id }
    }

    /// The suggestion after `step` taps of "Another": the planned order first,
    /// then round the list. nil on a non-office day.
    public static func suggestion(_ meals: MealDay?, orders: [LunchOrder], step: Int = 0) -> LunchOrder? {
        guard let planned = planned(meals, orders: orders),
              let first = orders.firstIndex(of: planned) else { return nil }
        return orders[(first + max(step, 0)) % orders.count]
    }
}
