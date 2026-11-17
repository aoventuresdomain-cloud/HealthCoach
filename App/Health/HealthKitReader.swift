import CoachCore
import Foundation
import HealthKit
import Observation

/// CoachCore's `HealthReading`, backed by HealthKit. Read-only: it asks for
/// read access to body mass and step count and never for write access.
/// Needs the HealthKit entitlement, so on the phone it waits for the paid
/// account (board: deferred to payment); the simulator and UI tests use
/// `SampleHealthReader`.
nonisolated struct HealthKitReader: HealthReading {
    /// One store for the app, as Apple recommends.
    nonisolated(unsafe) private static let sharedStore = HKHealthStore()
    private var store: HKHealthStore { Self.sharedStore }
    private var bodyMass: HKQuantityType { HKQuantityType(.bodyMass) }
    private var steps: HKQuantityType { HKQuantityType(.stepCount) }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestReadAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: [bodyMass, steps])
    }

    func weights(from start: Date, to end: Date) async throws -> [WeightSample] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMass, predicate: HKQuery.predicateForSamples(withStart: start, end: end))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        return try await descriptor.result(for: store).map {
            WeightSample(date: $0.startDate, kg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)))
        }
    }

    func dailySteps(from start: Date, to end: Date) async throws -> [StepCount] {
        let calendar = Calendar.current
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: steps, predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: .cumulativeSum,
            anchorDate: calendar.startOfDay(for: start),
            intervalComponents: DateComponents(day: 1))
        return try await descriptor.result(for: store).statistics().compactMap { statistics in
            guard statistics.startDate >= calendar.startOfDay(for: start), statistics.startDate < end,
                  let sum = statistics.sumQuantity() else { return nil }
            return StepCount(day: statistics.startDate, steps: Int(sum.doubleValue(for: .count())))
        }
    }
}

/// Sample data for the simulator and UI tests (board M2-04 Done when): 14
/// days of 06:00 weigh-ins drifting down about 0.3 kg a week, and steps.
/// Fixed values, so a test knows the average to expect.
nonisolated struct SampleHealthReader: HealthReading {
    /// The day the data ends on (the app's clock).
    let today: Date

    /// Last 7 days: 83.0, 82.9 … 82.4 (mean 82.7); the 7 before: 83.3 … 82.7 (mean 83.0).
    static func kg(daysAgo: Int) -> Double { 82.4 + Double(daysAgo) * 0.1 }

    func requestReadAccess() async throws {}

    func weights(from start: Date, to end: Date) async throws -> [WeightSample] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: today)
        return (0..<14).compactMap { ago in
            guard let date = calendar.date(byAdding: DateComponents(day: -ago, hour: 6), to: day),
                  date >= start, date < end else { return nil }
            return WeightSample(date: date, kg: Self.kg(daysAgo: ago))
        }
    }

    func dailySteps(from start: Date, to end: Date) async throws -> [StepCount] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: today)
        return (0..<8).compactMap { ago in
            guard let date = calendar.date(byAdding: .day, value: -ago, to: day),
                  date >= start, date < end else { return nil }
            return StepCount(day: date, steps: ago == 0 ? 3200 : 8000 + ago * 100)
        }
    }
}

/// Board M2-04: the weight trend and steps for Today and, later, Progress
/// (M4-03) and the rules engine (M4-01). Read on each open; nothing is
/// stored or sent anywhere, so no health data leaves the phone.
@MainActor
@Observable
final class BodyStats {
    static let shared = BodyStats()

    private(set) var weight: WeightTrend?
    /// The weigh-ins behind `weight` (last 14 days), for the Progress chart's
    /// faint daily dots. Shown on the phone only; never shared.
    private(set) var weightSamples: [WeightSample] = []
    private(set) var steps: StepsSummary?
    /// False until a read has finished (the debug line says "pending").
    private(set) var hasRead = false

    @ObservationIgnored private let reader: (any HealthReading)?

    init(reader: (any HealthReading)? = nil) {
        if let reader {
            self.reader = reader
        } else if LaunchOptions.current.isUITest {
            // A fixture's own Health data when it has some (A12), else the samples.
            let fixed = LaunchOptions.current.fixture.flatMap { try? Fixture.load(named: $0).health }
            self.reader = fixed ?? SampleHealthReader(today: AppClock.now())
        } else {
            #if targetEnvironment(simulator)
            // No entitlement without the paid account; sample data stands in.
            self.reader = SampleHealthReader(today: AppClock.now())
            #else
            self.reader = HealthKitReader.isAvailable ? HealthKitReader() : nil
            #endif
        }
    }

    /// Reads the last 14 days of weight and 8 days of steps. A refusal or an
    /// error leaves nothing shown; it never blocks the rest of the app.
    func refresh(now: Date = AppClock.now(), calendar: Calendar = .current) async {
        defer { hasRead = true }
        guard let reader else { return }
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let weightStart = calendar.date(byAdding: .day, value: -2 * WeightTrend.windowDays, to: end) ?? end
        let stepsStart = calendar.date(byAdding: .day, value: -8, to: end) ?? end
        do {
            try await reader.requestReadAccess()
            let samples = try await reader.weights(from: weightStart, to: end)
            weightSamples = samples
            weight = WeightTrend.make(samples: samples, endingOn: now, calendar: calendar)
            steps = StepsSummary.make(days: try await reader.dailySteps(from: stepsStart, to: end),
                                      today: now, calendar: calendar)
        } catch {
            weight = nil
            weightSamples = []
            steps = nil
        }
    }
}
