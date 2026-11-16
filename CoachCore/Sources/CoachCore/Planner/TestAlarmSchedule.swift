import Foundation

/// The spike S1 test plan (board M0-04): `count` alarms, the first about two
/// minutes ahead so the owner can watch it ring locked, on Silent and in Focus.
///
/// The rest are only there to prove that `count` alarms register and survive
/// a TestFlight update (S1b), so they start `laterStartDay` days out, one a day
/// at the first alarm's time: far enough that the M2 planner's reconcile
/// replaces them before any of them rings.
public enum TestAlarmSchedule {
    public static let title = "HealthCoach test alarm"

    public static func make(
        now: Date,
        calendar: Calendar = .current,
        count: Int = 14,
        firstAfter: TimeInterval = 120,
        laterStartDay: Int = 21,
        makeID: () -> UUID = UUID.init
    ) -> [PlannedAlarm] {
        guard count > 0 else { return [] }
        let first = roundedUpToMinute(now.addingTimeInterval(firstAfter), calendar: calendar)
        var alarms = [PlannedAlarm(id: makeID(), fireDate: first, title: title)]
        for offset in 0..<(count - 1) {
            guard let date = calendar.date(byAdding: .day, value: laterStartDay + offset, to: first) else { continue }
            alarms.append(PlannedAlarm(id: makeID(), fireDate: date, title: title))
        }
        return alarms
    }

    /// Splits a test plan for "Clear later test alarms": keeps anything due
    /// within `keepWithin` of `now` (the near test alarm), drops the rest.
    public static func splitForClearing(
        _ plan: [PlannedAlarm],
        now: Date,
        keepWithin: TimeInterval = 24 * 3600
    ) -> (keep: [PlannedAlarm], drop: [PlannedAlarm]) {
        let cutoff = now.addingTimeInterval(keepWithin)
        return (plan.filter { $0.fireDate <= cutoff }, plan.filter { $0.fireDate > cutoff })
    }

    /// Whole minutes read cleanly on screen ("next at 07:02").
    static func roundedUpToMinute(_ date: Date, calendar: Calendar) -> Date {
        let floored = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        return floored < date ? floored.addingTimeInterval(60) : floored
    }
}
