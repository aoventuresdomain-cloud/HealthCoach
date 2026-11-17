import Foundation

/// The Progress hero (board M4-03, UI pass): the 7-day average as a line,
/// one point per day that has a full window, with the weigh-ins as faint dots.
public enum WeightChart {
    public struct Point: Sendable, Equatable {
        public let day: Date
        public let averageKg: Double
    }

    /// The 7-day average for each of the `days` days ending on `today`, oldest
    /// first; days whose window has too few weigh-ins are left out.
    public static func averages(samples: [WeightSample], endingOn today: Date, days: Int = 8,
                                calendar: Calendar = .current) -> [Point] {
        let end = calendar.startOfDay(for: today)
        return (0..<days).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: end),
                  let trend = WeightTrend.make(samples: samples, endingOn: day, calendar: calendar) else { return nil }
            return Point(day: day, averageKg: trend.averageKg)
        }
    }
}

/// The phase line on Progress: "Phase 1 · week 3 of 6" over "Week 3 of about 20".
public enum PhaseLine {
    /// Plan §1: lean, strong and defined over 16–20 weeks.
    public static let aboutTotalWeeks = 20

    public static func lines(programme: Programme, start: Date?, on date: Date,
                             calendar: Calendar = .current) -> (phase: String, overall: String)? {
        guard let start, let week = programme.plannedDay(on: date, start: start, calendar: calendar).week else { return nil }
        return ("Phase \(programme.phase) · week \(week) of \(programme.weeks)", "Week \(week) of about \(aboutTotalWeeks)")
    }
}
