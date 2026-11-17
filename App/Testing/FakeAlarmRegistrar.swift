import CoachCore
import Foundation

/// Stands in for AlarmKit in UI tests (`-uitest`): records what would be
/// registered, never prompts, never rings.
actor FakeAlarmRegistrar: AlarmRegistering {
    private var registered: [UUID: PlannedAlarm] = [:]

    func registeredAlarmIDs() async throws -> Set<UUID> { Set(registered.keys) }
    func register(_ alarm: PlannedAlarm) async throws { registered[alarm.id] = alarm }
    func cancel(alarmID: UUID) async throws { registered[alarmID] = nil }
    /// QA-31: a fixture launch starts as if the alarms were already set.
    func seed(_ alarms: [PlannedAlarm]) { for alarm in alarms { registered[alarm.id] = alarm } }
}
