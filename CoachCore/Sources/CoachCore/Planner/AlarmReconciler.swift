import Foundation

/// What has to change on the phone for its alarms to match the plan.
public struct ReconcilePlan: Equatable, Sendable {
    /// Planned future alarms that are not registered (missing), soonest first.
    public let toRegister: [PlannedAlarm]
    /// Registered alarms the plan no longer wants, sorted for stable output.
    public let toCancel: [UUID]
    /// Planned alarms still in the future: what should be registered.
    public let upcoming: [PlannedAlarm]
}

/// What a reconcile did. `reSet` is how many missing alarms it registered again.
public struct ReconcileOutcome: Equatable, Sendable {
    public let total: Int
    public let reSet: Int
    public let cancelled: Int
    public let next: Date?
}

/// Compares the plan with what is registered and fills the gaps (plan §4.1,
/// spike S1b). Runs on every app open; there is no background job.
public enum AlarmReconciler {
    /// Pure comparison. Alarms due at or before `now` are ignored: they have
    /// fired or are firing, and AlarmKit no longer lists them as scheduled.
    ///
    /// Safety rule: a plan with nothing upcoming never cancels anything. An
    /// empty plan almost always means a failed or missing load, and wiping the
    /// owner's alarms on that is the worst failure this app can have. Clearing
    /// alarms on purpose goes through `AlarmRegistering.cancel` directly.
    public static func plan(planned: [PlannedAlarm], registered: Set<UUID>, now: Date) -> ReconcilePlan {
        let upcoming = planned
            .filter { $0.fireDate > now }
            .sorted { ($0.fireDate, $0.id.uuidString) < ($1.fireDate, $1.id.uuidString) }
        let wanted = Set(upcoming.map(\.id))
        return ReconcilePlan(
            toRegister: upcoming.filter { !registered.contains($0.id) },
            toCancel: upcoming.isEmpty
                ? []
                : registered.subtracting(wanted).sorted { $0.uuidString < $1.uuidString },
            upcoming: upcoming
        )
    }

    /// Reads the registered alarms, registers the missing ones and cancels the
    /// ones the plan dropped. Stops at the first registration error so the
    /// caller can show it; a later open retries.
    public static func reconcile(
        planned: [PlannedAlarm],
        using registrar: some AlarmRegistering,
        now: Date
    ) async throws -> ReconcileOutcome {
        let registered = try await registrar.registeredAlarmIDs()
        let changes = plan(planned: planned, registered: registered, now: now)
        for alarm in changes.toRegister {
            try await registrar.register(alarm)
        }
        for id in changes.toCancel {
            try await registrar.cancel(alarmID: id)
        }
        return ReconcileOutcome(
            total: changes.upcoming.count,
            reSet: changes.toRegister.count,
            cancelled: changes.toCancel.count,
            next: changes.upcoming.first?.fireDate
        )
    }
}
