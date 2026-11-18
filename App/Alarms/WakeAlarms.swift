import CoachCore
import Foundation
import Observation

/// The Sunday prompt's answers, one entry per week (keyed by its Monday).
/// Office days and start times only: no health data. Weeks not yet answered
/// use the latest earlier answers, so alarms 14 days out are sensible.
@MainActor
final class WeekAnswersStore {
    private let defaults: UserDefaults
    private let key = "planner.weekAnswers.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The app's store. UI tests (without -realAlarms) get a clean one every
    /// launch, so a Sunday prompt test always starts unanswered.
    static let shared: WeekAnswersStore = {
        let options = LaunchOptions.current
        guard options.isUITest && !options.realAlarms,
              let suite = UserDefaults(suiteName: "uitest.weekAnswers") else { return WeekAnswersStore() }
        suite.removePersistentDomain(forName: "uitest.weekAnswers")
        return WeekAnswersStore(defaults: suite)
    }()

    /// True once the Sunday prompt has been answered for that exact week.
    func hasAnswers(weekStarting monday: Date, calendar: Calendar = .current) -> Bool {
        all[Self.key(monday, calendar: calendar)] != nil
    }

    private var all: [String: WeekAnswers] {
        get {
            guard let data = defaults.data(forKey: key) else { return [:] }
            return (try? JSONDecoder().decode([String: WeekAnswers].self, from: data)) ?? [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: key) }
        }
    }

    func save(_ answers: WeekAnswers, weekStarting monday: Date, calendar: Calendar = .current) {
        var stored = all
        stored[Self.key(monday, calendar: calendar)] = answers
        all = stored
    }

    /// Forgets every week's answers (UI test fixtures start clean).
    func removeAll() {
        defaults.removeObject(forKey: key)
    }

    /// The answers for the week starting `monday`, else the latest earlier week's, else none.
    func answers(weekStarting monday: Date, calendar: Calendar = .current) -> WeekAnswers {
        let wanted = Self.key(monday, calendar: calendar)
        let stored = all
        if let exact = stored[wanted] { return exact }
        // Keys are yyyy-MM-dd, so string order is date order.
        return stored.keys.filter { $0 < wanted }.max().flatMap { stored[$0] } ?? WeekAnswers()
    }

    private static func key(_ monday: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: monday)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// Board M2-02: on every open, the next 14 days of wake alarms from the week
/// planner are reconciled against AlarmKit. No background job.
///
/// Until onboarding sets a start date there is no plan, and the spike's test
/// alarms (M0-04) keep their own reconcile; after that this one owns the
/// app's alarms and replaces any test alarms left over.
@MainActor
@Observable
final class WakeAlarms {
    static let shared = WakeAlarms()

    /// Today's warning line reads this (QA-1: no alarms is always a warning).
    private(set) var coverage: AlarmCoverage?
    private(set) var lastError: String?
    /// Set once the planner has reconciled this launch; the spike screen then
    /// stops touching AlarmKit, so it can never cancel a wake alarm.
    private(set) var ownsAlarms = false

    @ObservationIgnored private let registrar: any AlarmRegistering
    @ObservationIgnored private let isAuthorized: () -> Bool
    /// QA-31: under -uitest the fake store is filled with the first plan, so
    /// review shots don't all say "N alarms were missing" (not with -missingAlarms).
    @ObservationIgnored private var seedFakeOnce = false

    private init() {
        if LaunchOptions.current.isUITest && !LaunchOptions.current.realAlarms {
            registrar = FakeAlarmRegistrar()
            let denied = LaunchOptions.current.denyAlarms
            isAuthorized = { !denied }
            seedFakeOnce = !LaunchOptions.current.missingAlarms
        } else {
            let alarmKit = AlarmKitRegistrar()
            registrar = alarmKit
            isAuthorized = { alarmKit.isAuthorized }
        }
    }

    /// True when the planner owns the alarms (onboarding has set a start date).
    func isActive(profile: Profile?) -> Bool {
        profile?.programme.startDate != nil && !LaunchOptions.current.spikeAlarms
    }

    /// Builds the 14-day plan and reconciles it. `history` is every logged
    /// session, for the reduced week (`Programme.droppedSessions(history:)`). Never prompts for permission:
    /// onboarding asks. Without permission the coverage is `.noAlarms`.
    @discardableResult
    func reconcile(profile: Profile, history: [SessionLog] = [], now: Date = AppClock.now(),
                   answers: WeekAnswersStore = .shared) async -> AlarmCoverage {
        lastError = nil
        ownsAlarms = true
        guard isAuthorized() else {
            coverage = .noAlarms
            return .noAlarms
        }
        guard let content = try? BundledContent.load(),
              let programme = content.programme(for: profile, on: now, calendar: .coach) else {
            // Never reconcile against a plan that didn't load (empty-plan guard).
            lastError = "The training plan couldn't be read, so alarms were left as they were."
            coverage = .noAlarms
            return .noAlarms
        }
        // Two "Sore" answers in a row drop the reduced week's session (decision R2)
        // until a "Fine" answer lifts it; its day then gets no session alarm.
        // An accepted Claude block's dropped sessions too (M4-02).
        let dropping = CoachBlockStore().droppedSessions(programme: programme, history: history,
                                                         profile: profile, on: now)
        // E13: an unlogged session whose time has passed moves (logged this week = done).
        let planned = AlarmSchedule.make(now: now, programme: programme, profile: profile,
                                         answers: { answers.answers(weekStarting: $0) }, dropping: dropping,
                                         completed: SessionLog.sessionIDs(in: history, weekOf: now))
        if seedFakeOnce, let fake = registrar as? FakeAlarmRegistrar {
            seedFakeOnce = false
            await fake.seed(planned)
        }
        do {
            let outcome = try await AlarmReconciler.reconcile(planned: planned, using: registrar, now: now)
            let result = AlarmCoverage(outcome)
            coverage = result
            return result
        } catch {
            lastError = error.localizedDescription
            coverage = .noAlarms
            return .noAlarms
        }
    }
}
