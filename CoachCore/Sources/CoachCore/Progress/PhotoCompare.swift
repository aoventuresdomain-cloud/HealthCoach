import Foundation

/// N7: which photo set the latest is compared against.
public enum PhotoCompare {
    public enum Against: String, CaseIterable, Sendable {
        case weekZero = "Week 0"
        case fourWeeksAgo = "4 weeks ago"
    }

    /// Index into `dates` (oldest first) of the set to compare the latest with:
    /// the first set, or the newest one at least 28 days before the latest
    /// (the first set when none is that old). Nil with fewer than two sets.
    public static func baseline(_ dates: [Date], against: Against, calendar: Calendar = .current) -> Int? {
        guard dates.count >= 2, let latest = dates.last else { return nil }
        switch against {
        case .weekZero:
            return dates.startIndex
        case .fourWeeksAgo:
            guard let cutoff = calendar.date(byAdding: .day, value: -28, to: calendar.startOfDay(for: latest)) else {
                return dates.startIndex
            }
            return dates.dropLast().lastIndex { calendar.startOfDay(for: $0) <= cutoff } ?? dates.startIndex
        }
    }
}
