import CoachCore
import Foundation

/// Spike S1/S1b runner behind the Spike tests screen (board M0-04, M0-05, M0-11).
///
/// The test plan, with its alarm ids, is stored on the phone when "Set test
/// alarms" is tapped and only replaced by another tap, so after a TestFlight
/// update the reconcile compares the same ids and S1b shows whether AlarmKit
/// kept them. Every app open reconciles against that stored plan.
@MainActor
final class AlarmKitSpike: AlarmSpikeRunning {
    static let shared = AlarmKitSpike()

    private let registrar: any AlarmRegistering
    private let requestAuthorization: () async throws -> Bool
    private let store: UserDefaults

    private init() {
        if LaunchOptions.current.isUITest && !LaunchOptions.current.realAlarms {
            // UI tests: no prompt, no real alarms, a clean store every launch.
            registrar = FakeAlarmRegistrar()
            requestAuthorization = { true }
            store = UserDefaults(suiteName: "uitest.alarms") ?? .standard
            store.removePersistentDomain(forName: "uitest.alarms")
        } else {
            let alarmKit = AlarmKitRegistrar()
            registrar = alarmKit
            requestAuthorization = { try await alarmKit.requestAuthorization() }
            store = .standard
        }
    }
    private let planKey = "spike.testAlarmPlan.v1"
    private var lastStatus: AlarmReconcileStatus = .notYetRun
    private var inFlight: Task<AlarmReconcileStatus, Never>?

    nonisolated enum SpikeError: LocalizedError {
        case permissionDenied
        case planUnreadable
        case plannerOwnsAlarms

        var errorDescription: String? {
            switch self {
            case .permissionDenied: "Alarm permission is off. Turn it on in Settings › HealthCoach › Alarms."
            case .planUnreadable: "The saved alarm plan couldn't be read, so nothing was changed."
            case .plannerOwnsAlarms: "The planner sets the alarms now, so test alarms are off."
            }
        }
    }

    func setTestAlarms() async throws -> AlarmSpikeSummary {
        guard !WakeAlarms.shared.ownsAlarms else { throw SpikeError.plannerOwnsAlarms }
        guard try await requestAuthorization() else { throw SpikeError.permissionDenied }
        let plan = TestAlarmSchedule.make(now: AppClock.now())
        try save(plan)
        // Registers the new plan and cancels any earlier test alarms.
        let outcome = try await AlarmReconciler.reconcile(planned: plan, using: registrar, now: AppClock.now())
        lastStatus = .allSet(count: outcome.total)
        return AlarmSpikeSummary(count: outcome.total, next: outcome.next)
    }

    /// Cancels the 13 test alarms set 21+ days out, keeping the near one, in
    /// case the M2 planner isn't there to replace them in time.
    func clearLaterTestAlarms() async throws -> AlarmSpikeSummary {
        guard !WakeAlarms.shared.ownsAlarms else { throw SpikeError.plannerOwnsAlarms }
        guard let plan = try loadPlan() else { return AlarmSpikeSummary(count: 0, next: nil) }
        let split = TestAlarmSchedule.splitForClearing(plan, now: AppClock.now())
        for alarm in split.drop {
            // Already gone (fired or dropped by an update) is fine.
            try? await registrar.cancel(alarmID: alarm.id)
        }
        try save(split.keep)
        let now = AppClock.now()
        let upcoming = split.keep.filter { $0.fireDate > now }
        lastStatus = .allSet(count: upcoming.count)
        return AlarmSpikeSummary(count: upcoming.count, next: upcoming.map(\.fireDate).min())
    }

    /// Reconciles against the stored plan. The app calls it on every open; the
    /// screen shows `notYetRun` (a warning) until the first one has finished.
    /// A re-set stays reported for the rest of the launch, so the S1b evidence
    /// ("the update dropped N alarms") is still on screen when the owner looks.
    func reconcileStatus() async -> AlarmReconcileStatus {
        if let inFlight { return await inFlight.value }
        let task = Task { await runReconcile() }
        inFlight = task
        let status = await task.value
        inFlight = nil
        return status
    }

    private func runReconcile() async -> AlarmReconcileStatus {
        if WakeAlarms.shared.ownsAlarms {
            // Report the planner's result; never reconcile the test plan over it.
            switch WakeAlarms.shared.coverage {
            case let .allSet(count, _)?: lastStatus = .allSet(count: count)
            case let .reSet(missing, total, _)?: lastStatus = .reSet(missing: missing, total: total)
            case .noAlarms?: lastStatus = .allSet(count: 0)
            case nil: lastStatus = .notYetRun
            }
            return lastStatus
        }
        let plan: [PlannedAlarm]
        do {
            guard let stored = try loadPlan() else {
                // Nothing set yet: don't touch AlarmKit, so no prompt and no error.
                lastStatus = .allSet(count: 0)
                return lastStatus
            }
            plan = stored
        } catch {
            // Never reconcile against a plan we couldn't read: that could
            // cancel alarms the owner relies on.
            lastStatus = .failed(error.localizedDescription)
            return lastStatus
        }
        do {
            let outcome = try await AlarmReconciler.reconcile(planned: plan, using: registrar, now: AppClock.now())
            if outcome.reSet > 0 {
                lastStatus = .reSet(missing: outcome.reSet, total: outcome.total)
            } else if case .reSet = lastStatus {
                // Keep showing this launch's re-set.
            } else {
                lastStatus = .allSet(count: outcome.total)
            }
        } catch {
            lastStatus = .failed(error.localizedDescription)
        }
        return lastStatus
    }

    private func save(_ plan: [PlannedAlarm]) throws {
        store.set(try JSONEncoder().encode(plan), forKey: planKey)
    }

    /// nil when no plan has been stored; throws when one is stored but unreadable.
    private func loadPlan() throws -> [PlannedAlarm]? {
        guard let data = store.data(forKey: planKey) else { return nil }
        do {
            return try JSONDecoder().decode([PlannedAlarm].self, from: data)
        } catch {
            throw SpikeError.planUnreadable
        }
    }
}
