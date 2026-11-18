import CoachCore
import Foundation

/// N1: one Sunday check-in, the answers from screen 1. Defaults are Good,
/// Fine and no pain (Advisor A1), so an ordinary week is just Next.
nonisolated struct CheckInAnswers: Codable, Equatable, Sendable {
    enum Energy: String, Codable, CaseIterable, Sendable { case good = "Good", ok = "OK", low = "Low" }
    enum Sleep: String, Codable, CaseIterable, Sendable { case fine = "Fine", poor = "Poor" }
    enum PainArea: String, Codable, CaseIterable, Sendable {
        case shoulder = "Shoulder", elbow = "Elbow", wrist = "Wrist", back = "Back", knee = "Knee", other = "Other"
    }

    var energy = Energy.good
    var sleep = Sleep.fine
    /// Empty means "None".
    var pain: Set<PainArea> = []

    /// Energy Low and Sleep Poor together are one low-recovery signal (Advisor 3).
    var isLowRecovery: Bool { energy == .low && sleep == .poor }
}

/// The check-ins, one per week, keyed by the Monday they plan. Kept on the
/// phone; the coach summary reads them, nothing else leaves the device.
@MainActor
final class CheckInStore {
    static let shared = CheckInStore()

    private let defaults: UserDefaults
    private let key = "checkIn.weeks.v1"

    private init() {
        // UI tests start unanswered, like the Sunday prompt.
        if LaunchOptions.current.isUITest, let suite = UserDefaults(suiteName: "uitest.checkIn") {
            suite.removePersistentDomain(forName: "uitest.checkIn")
            defaults = suite
        } else {
            defaults = .standard
        }
    }

    func answers(weekStarting monday: Date, calendar: Calendar) -> CheckInAnswers? {
        all[SocialMealStore.dayKey(monday, calendar: calendar)]
    }

    func hasCheckedIn(weekStarting monday: Date, calendar: Calendar) -> Bool {
        answers(weekStarting: monday, calendar: calendar) != nil
    }

    func save(_ answers: CheckInAnswers, weekStarting monday: Date, calendar: Calendar) {
        var stored = all
        stored[SocialMealStore.dayKey(monday, calendar: calendar)] = answers
        all = stored
    }

    /// Every week's answers, keyed "yyyy-MM-dd" (the Monday).
    var all: [String: CheckInAnswers] {
        get {
            guard let data = defaults.data(forKey: key) else { return [:] }
            return (try? JSONDecoder().decode([String: CheckInAnswers].self, from: data)) ?? [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: key) }
        }
    }
}
