import Foundation

/// Lower-case English day names, as used in content files and the profile.
public enum Weekday: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable, Comparable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    /// Monday-first order, as the programme schedule is written.
    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }

    /// From `Calendar.component(.weekday, …)` (1 = Sunday … 7 = Saturday).
    public init(calendarWeekday: Int) {
        let mondayFirst = (calendarWeekday + 5) % 7
        self = Weekday.allCases[mondayFirst]
    }
}

/// A clock time stored as "HH:mm".
public struct TimeOfDay: Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        precondition((0..<24).contains(hour) && (0..<60).contains(minute), "invalid time \(hour):\(minute)")
        self.hour = hour
        self.minute = minute
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }
    public var description: String { String(format: "%02d:%02d", hour, minute) }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        let parts = text.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "expected HH:mm, found \"\(text)\""))
        }
        self.init(hour: h, minute: m)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
