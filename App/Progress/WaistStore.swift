import CoachCore
import Foundation

/// N7: the optional waist measurement on photo day (Advisor 5), off until
/// turned on in Preferences. One value per photo day, in cm; kept on the
/// phone and never shared.
@MainActor
final class WaistStore {
    static let shared = WaistStore()

    /// The stepper's start before any measurement.
    static let firstGuessCm = 90.0
    static let stepCm = 0.5
    static let range = 50.0...160.0

    private let defaults: UserDefaults
    private let onKey = "progress.waist.on.v1"
    private let valuesKey = "progress.waist.cm.v1"

    private init() {
        if LaunchOptions.current.isUITest, let suite = UserDefaults(suiteName: "uitest.waist") {
            suite.removePersistentDomain(forName: "uitest.waist")
            defaults = suite
        } else {
            defaults = .standard
        }
    }

    var isOn: Bool {
        get { defaults.bool(forKey: onKey) }
        set { defaults.set(newValue, forKey: onKey) }
    }

    /// The latest measurement, if any.
    var last: (day: String, cm: Double)? {
        values.max { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    func save(_ cm: Double, on date: Date, calendar: Calendar) {
        var stored = values
        stored[SocialMealStore.dayKey(date, calendar: calendar)] = (cm / Self.stepCm).rounded() * Self.stepCm
        defaults.set(stored, forKey: valuesKey)
    }

    /// "86.5 cm".
    static func text(_ cm: Double) -> String { "\(WeightTrend.oneDecimal(cm)) cm" }

    private var values: [String: Double] {
        (defaults.dictionary(forKey: valuesKey) as? [String: Double]) ?? [:]
    }
}
