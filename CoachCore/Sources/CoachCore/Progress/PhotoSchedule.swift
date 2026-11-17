import Foundation

/// Progress photos every 2 weeks (plan §4.6, board M4-03). The 2-week blocks
/// start on `programme.startDate`; a block's photo day is its first day, and
/// it stays due for the rest of the block until a set is taken. A missed
/// block is never carried over: no backlog, no guilt copy.
public enum PhotoSchedule {
    public static let intervalDays = 14

    /// The first day of the 2-week block holding `date`; nil before the start.
    public static func blockStart(for date: Date, start: Date, calendar: Calendar = .current) -> Date? {
        let first = calendar.startOfDay(for: start)
        let day = calendar.startOfDay(for: date)
        guard day >= first,
              let days = calendar.dateComponents([.day], from: first, to: day).day else { return nil }
        return calendar.date(byAdding: .day, value: (days / intervalDays) * intervalDays, to: first)
    }

    /// True when this block has no photo yet. `taken` are the days photos were saved.
    public static func isDue(on date: Date, start: Date?, taken: [Date], calendar: Calendar = .current) -> Bool {
        guard let start, let block = blockStart(for: date, start: start, calendar: calendar),
              let end = calendar.date(byAdding: .day, value: intervalDays, to: block) else { return false }
        return !taken.contains { $0 >= block && $0 < end }
    }

    /// The next block's first day after `date` (for "Next photos Mon 30 Nov").
    public static func nextPhotoDay(after date: Date, start: Date, calendar: Calendar = .current) -> Date? {
        guard let block = blockStart(for: date, start: start, calendar: calendar) else {
            return calendar.startOfDay(for: start)
        }
        return calendar.date(byAdding: .day, value: intervalDays, to: block)
    }

    /// yyyy-MM-dd in `calendar`, the name a photo set is saved under.
    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
