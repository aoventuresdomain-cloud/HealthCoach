import Foundation

// Board M2-04: weight 7-day trend and steps, read-only from Apple Health.
// The smart scale writes to Health; the app only reads, and no health data
// leaves the phone (project rule). HealthKit itself stays in the app target
// behind `HealthReading`, so this logic is tested on Linux.

/// One weigh-in.
public struct WeightSample: Sendable, Equatable {
    public let date: Date
    public let kg: Double

    public init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

/// Steps for one calendar day (`day` is its start).
public struct StepCount: Sendable, Equatable {
    public let day: Date
    public let steps: Int

    public init(day: Date, steps: Int) {
        self.day = day
        self.steps = steps
    }
}

/// Read-only access to the owner's weight and steps. The app backs it with
/// HealthKit on the phone and with sample data in the simulator and UI tests.
public protocol HealthReading: Sendable {
    /// Asks once for read access to weight and steps. Never asks to write.
    func requestReadAccess() async throws
    /// Weigh-ins in `start..<end`, any order.
    func weights(from start: Date, to end: Date) async throws -> [WeightSample]
    /// One entry per day with steps in `start..<end`.
    func dailySteps(from start: Date, to end: Date) async throws -> [StepCount]
}

/// The 7-day average weight (plan §4: "the 7-day average beats one weekly
/// number") and how it moved against the 7 days before.
public struct WeightTrend: Sendable, Equatable {
    /// Mean of the daily weights in the 7 days ending on the given day.
    public let averageKg: Double
    /// Days in the window with at least one weigh-in.
    public let daysWeighed: Int
    /// The same average for the 7 days before, when it has enough days.
    public let previousAverageKg: Double?

    /// Change against the previous 7 days; negative is a loss.
    public var changeKg: Double? { previousAverageKg.map { averageKg - $0 } }

    public static let windowDays = 7
    /// Fewer weigh-ins than this in a window gives no average: one or two
    /// readings are too noisy to call a trend.
    public static let minimumDays = 3
    /// Readings outside this range are scale glitches (a child, a bag) and are ignored.
    public static let plausibleKg: ClosedRange<Double> = 30...250

    /// The trend for the 7 days ending on `day` (inclusive). A day with
    /// several weigh-ins counts once, at their mean. Nil without enough days.
    public static func make(samples: [WeightSample], endingOn day: Date, calendar: Calendar) -> WeightTrend? {
        let lastDay = calendar.startOfDay(for: day)
        var byDay: [Date: [Double]] = [:]
        for sample in samples where plausibleKg.contains(sample.kg) {
            byDay[calendar.startOfDay(for: sample.date), default: []].append(sample.kg)
        }
        let daily = byDay.mapValues { $0.reduce(0, +) / Double($0.count) }

        func window(endingOn end: Date) -> (average: Double, days: Int)? {
            guard let first = calendar.date(byAdding: .day, value: -(windowDays - 1), to: end) else { return nil }
            // In date order: summing in dictionary order made the last bits of the
            // average differ between calls, so equal inputs compared unequal.
            let values = daily.filter { $0.key >= first && $0.key <= end }.sorted { $0.key < $1.key }.map(\.value)
            guard values.count >= minimumDays else { return nil }
            return (values.reduce(0, +) / Double(values.count), values.count)
        }

        guard let current = window(endingOn: lastDay) else { return nil }
        let previousEnd = calendar.date(byAdding: .day, value: -windowDays, to: lastDay)
        return WeightTrend(averageKg: current.average, daysWeighed: current.days,
                           previousAverageKg: previousEnd.flatMap { window(endingOn: $0)?.average })
    }

    /// "82.4 kg (7-day average), down 0.6 kg on last week".
    public var summary: String {
        let average = "\(Self.oneDecimal(averageKg)) kg (7-day average)"
        guard let change = changeKg else { return average }
        let rounded = (change * 10).rounded() / 10
        if rounded == 0 { return "\(average), level with last week" }
        return "\(average), \(rounded < 0 ? "down" : "up") \(Self.oneDecimal(abs(rounded))) kg on last week"
    }

    /// One decimal place without `String(format:)`, which differs on Linux.
    public static func oneDecimal(_ value: Double) -> String {
        let tenths = Int((value * 10).rounded())
        return "\(tenths / 10).\(abs(tenths % 10))"
    }
}

/// Today's steps and the daily average over the 7 days before today.
public struct StepsSummary: Sendable, Equatable {
    public let today: Int
    /// Mean over the previous 7 days that have any steps; nil when none do.
    public let sevenDayAverage: Int?

    public static func make(days: [StepCount], today day: Date, calendar: Calendar) -> StepsSummary {
        let todayStart = calendar.startOfDay(for: day)
        var byDay: [Date: Int] = [:]
        for entry in days { byDay[calendar.startOfDay(for: entry.day), default: 0] += max(0, entry.steps) }
        let first = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        let previous = byDay.filter { $0.key >= first && $0.key < todayStart && $0.value > 0 }.map(\.value)
        return StepsSummary(
            today: byDay[todayStart] ?? 0,
            sevenDayAverage: previous.isEmpty ? nil : Int((Double(previous.reduce(0, +)) / Double(previous.count)).rounded()))
    }
}

/// Fixed weigh-ins and steps, for UI-test fixtures (Gate 1–2 checklist A12):
/// the JSON `health` key, `{"weights": [{"date", "kg"}], "steps": [{"day", "steps"}]}`,
/// dates in ISO 8601. Returns only what falls in the asked range.
public struct FixedHealthReader: HealthReading, Decodable, Equatable {
    public let weights: [WeightSample]
    public let steps: [StepCount]

    public init(weights: [WeightSample], steps: [StepCount]) {
        self.weights = weights
        self.steps = steps
    }

    private struct Weight: Decodable { let date: Date; let kg: Double }
    private struct Steps: Decodable { let day: Date; let steps: Int }
    private enum Keys: String, CodingKey { case weights, steps }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        weights = try (c.decodeIfPresent([Weight].self, forKey: .weights) ?? []).map { WeightSample(date: $0.date, kg: $0.kg) }
        steps = try (c.decodeIfPresent([Steps].self, forKey: .steps) ?? []).map { StepCount(day: $0.day, steps: $0.steps) }
    }

    public func requestReadAccess() async throws {}

    public func weights(from start: Date, to end: Date) async throws -> [WeightSample] {
        weights.filter { $0.date >= start && $0.date < end }
    }

    public func dailySteps(from start: Date, to end: Date) async throws -> [StepCount] {
        steps.filter { $0.day >= start && $0.day < end }
    }
}
