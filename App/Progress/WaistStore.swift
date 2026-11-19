import CoachCore
import Foundation

/// N7: the optional waist measurement on photo day (Advisor 5), off until
/// turned on in Preferences. The values are a `WaistLog` (CoachCore); kept
/// on the phone, and in the Claude summary only at checkpoints.
@MainActor
final class WaistStore {
    static let shared = WaistStore()

    private let defaults: UserDefaults
    private let onKey = "progress.waist.on.v1"
    private let logKey = "progress.waist.log.v1"

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

    var log: WaistLog {
        guard let data = defaults.data(forKey: logKey),
              let log = try? JSONDecoder().decode(WaistLog.self, from: data) else { return WaistLog() }
        return log
    }

    /// The log for the summary and the Progress line: only while the waist is on.
    var shownLog: WaistLog? { isOn ? log : nil }

    func save(_ cm: Double, on date: Date, calendar: Calendar) {
        var updated = log
        updated.add(cm: cm, on: date, calendar: calendar)
        if let data = try? JSONEncoder().encode(updated) { defaults.set(data, forKey: logKey) }
    }

    /// "86.5 cm", for the stepper.
    static func text(_ cm: Double) -> String { "\(WeightTrend.oneDecimal(cm)) cm" }
}
