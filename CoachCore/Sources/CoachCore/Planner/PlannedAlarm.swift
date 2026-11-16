import Foundation

/// One alarm the plan wants on the phone. The id is the AlarmKit alarm id, so
/// the plan and the registered alarms can be compared directly.
public struct PlannedAlarm: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let fireDate: Date
    public let title: String

    public init(id: UUID = UUID(), fireDate: Date, title: String) {
        self.id = id
        self.fireDate = fireDate
        self.title = title
    }
}

/// The phone's alarm system, seen from CoachCore. The app implements it with
/// AlarmKit; tests use a fake. Implementations only ever see this app's alarms.
public protocol AlarmRegistering: Sendable {
    /// Ids of the alarms currently registered and not yet fired.
    func registeredAlarmIDs() async throws -> Set<UUID>
    func register(_ alarm: PlannedAlarm) async throws
    func cancel(alarmID: UUID) async throws
}
