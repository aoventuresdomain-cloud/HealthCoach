import Foundation

// Board N7: the Progress screen's data, so the app only draws it.
// - Waist (Advisor A3): optional, off by default, measured on photo day at the
//   navel after breathing out, kept on the phone. It reaches Claude only in a
//   checkpoint summary, as the latest value and the change since the first.
// - Photo pairing: which past photo sits beside today's, and which one is the
//   ghost outline. Photos never leave the app; the core sees dates only.
// - The one line under the photos: weight trend and, when on, waist.

/// One waist measurement.
public struct WaistEntry: Codable, Sendable, Equatable {
    public let date: Date
    public let cm: Double

    public init(date: Date, cm: Double) {
        self.date = date
        self.cm = cm
    }
}

/// The waist row: one value a day, in 0.5 cm steps, oldest first.
public struct WaistLog: Codable, Sendable, Equatable {
    public static let stepCm = 0.5
    public static let rangeCm: ClosedRange<Double> = 50...160
    /// The stepper's first value before anything is logged.
    public static let fallbackCm = 90.0

    public private(set) var entries: [WaistEntry]

    public init(entries: [WaistEntry] = []) {
        self.entries = entries.sorted { $0.date < $1.date }
    }

    /// `cm` on the 0.5 cm step, kept inside the range.
    public static func rounded(_ cm: Double) -> Double {
        let stepped = (cm / stepCm).rounded() * stepCm
        return min(rangeCm.upperBound, max(rangeCm.lowerBound, stepped))
    }

    /// Logs `cm` on the day of `date`, replacing that day's value if there is one.
    /// Ignores a value that isn't a number.
    public mutating func add(cm: Double, on date: Date, calendar: Calendar = .current) {
        guard cm.isFinite else { return }
        let day = calendar.startOfDay(for: date)
        entries.removeAll { calendar.isDate($0.date, inSameDayAs: day) }
        entries.append(WaistEntry(date: day, cm: Self.rounded(cm)))
        entries.sort { $0.date < $1.date }
    }

    public var last: WaistEntry? { entries.last }

    /// What the stepper starts on: the last value, or 90 cm.
    public var prefillCm: Double { last?.cm ?? Self.fallbackCm }

    /// Latest minus first; nil with fewer than two entries.
    public var changeCm: Double? {
        guard entries.count > 1, let first = entries.first, let last else { return nil }
        return last.cm - first.cm
    }

    /// "waist 88.5 cm (−1.5)"; "waist 88.5 cm" for the first entry; nil when empty.
    public var text: String? {
        guard let last else { return nil }
        let base = "waist \(CoachText.number(last.cm)) cm"
        guard let change = changeCm else { return base }
        return base + " (\(Self.signed(change)))"
    }

    /// The checkpoint summary's line: averages only, never the daily values.
    func summaryLine(calendar: Calendar) -> String? {
        guard let last else { return nil }
        var line = "- Waist (navel, photo day): \(CoachText.number(last.cm)) cm"
        if let change = changeCm, let first = entries.first {
            line += ", \(Self.signed(change)) cm since \(CoachText.day(first.date, calendar: calendar))"
        }
        return line
    }

    /// "−1.5", "+0.5", "level".
    static func signed(_ value: Double) -> String {
        let tenths = Int((value * 10).rounded())
        if tenths == 0 { return "level" }
        return (tenths < 0 ? "\u{2212}" : "+") + CoachText.number(abs(value))
    }
}

/// Which past photo of a pose sits beside today's. Works on the dates of one
/// pose's photos (any order) and returns indexes into them.
public enum PhotoPairing {
    /// The compare control's choices; the raw values are the labels the UI tests use.
    public enum Against: String, CaseIterable, Sendable {
        case weekZero = "Week 0"
        case fourWeeksAgo = "4 weeks ago"
    }

    public static let fourWeeksDays = 28
    /// "4 weeks ago" never picks a photo closer to today than one photo block.
    public static let minimumGapDays = PhotoSchedule.intervalDays

    /// Today's photo: the latest.
    public static func today(_ dates: [Date]) -> Int? {
        dates.indices.max { dates[$0] < dates[$1] }
    }

    /// The ghost outline for a new photo of this pose: the first one taken.
    public static func ghost(_ dates: [Date]) -> Int? {
        dates.indices.min { dates[$0] < dates[$1] }
    }

    /// The photo to show beside today's, or nil when there isn't one yet.
    /// Week 0: the first photo. 4 weeks ago: the one nearest 28 days before
    /// today's, at least 14 days before it; the earlier on a tie.
    public static func baseline(_ dates: [Date], against: Against, calendar: Calendar = .current) -> Int? {
        guard let today = today(dates) else { return nil }
        let todayDay = calendar.startOfDay(for: dates[today])
        func daysBefore(_ index: Int) -> Int {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: dates[index]), to: todayDay).day ?? 0
        }
        let earlier = dates.indices.filter { $0 != today && daysBefore($0) > 0 }
        switch against {
        case .weekZero:
            return earlier.min { dates[$0] < dates[$1] }
        case .fourWeeksAgo:
            return earlier.filter { daysBefore($0) >= minimumGapDays }.min { a, b in
                let da = abs(daysBefore(a) - fourWeeksDays), db = abs(daysBefore(b) - fourWeeksDays)
                return da != db ? da < db : dates[a] < dates[b]
            }
        }
    }

    /// The choices that have a photo to compare with, in the control's order.
    public static func available(_ dates: [Date], calendar: Calendar = .current) -> [Against] {
        Against.allCases.filter { baseline(dates, against: $0, calendar: calendar) != nil }
    }
}

/// The one line under the photos and on Progress.
public enum ProgressLine {
    /// "82.4 kg · 7-day average · −1.1 kg since start · waist 88.5 cm (−1.5)".
    /// Pass `waist` only when the waist row is on. Nil when there's nothing to say.
    public static func text(trend: WeightTrend?, changeSinceStart: Double?, waist: WaistLog? = nil) -> String? {
        var parts: [String] = []
        if let trend {
            parts.append("\(WeightTrend.oneDecimal(trend.averageKg)) kg · " + WeightTrend.heroSubline(changeSinceStart: changeSinceStart))
        }
        if let waist = waist?.text { parts.append(waist) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
