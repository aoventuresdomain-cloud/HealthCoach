import AlarmKit
import CoachCore
import Foundation
import SwiftUI

/// CoachCore's `AlarmRegistering`, backed by AlarmKit. The only file that
/// talks to AlarmKit for scheduling; the logic lives in CoachCore.
nonisolated struct AlarmKitRegistrar: AlarmRegistering {
    /// AlarmKit needs a metadata type; HealthCoach carries none yet.
    nonisolated struct Metadata: AlarmMetadata {}

    private var manager: AlarmManager { .shared }

    /// Asks once; later calls return the stored answer without a prompt.
    func requestAuthorization() async throws -> Bool {
        switch manager.authorizationState {
        case .authorized: return true
        case .denied: return false
        case .notDetermined: return try await manager.requestAuthorization() == .authorized
        @unknown default: return false
        }
    }

    /// Permission already granted; never prompts.
    var isAuthorized: Bool { manager.authorizationState == .authorized }

    func registeredAlarmIDs() async throws -> Set<UUID> {
        Set(try manager.alarms.map(\.id))
    }

    func register(_ alarm: PlannedAlarm) async throws {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.title),
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
        )
        let attributes = AlarmAttributes<Metadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: nil,
            tintColor: .green
        )
        let configuration = AlarmManager.AlarmConfiguration<Metadata>(
            schedule: .fixed(alarm.fireDate),
            attributes: attributes
        )
        _ = try await manager.schedule(id: alarm.id, configuration: configuration)
    }

    func cancel(alarmID: UUID) async throws {
        try manager.cancel(id: alarmID)
    }
}
