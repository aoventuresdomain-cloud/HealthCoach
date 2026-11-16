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
        // AlarmKit sometimes refuses a schedule call made straight after
        // others (seen in CI as "error 0" on the 4th of 14 quick calls, which a
        // later reconcile then set fine). Retry with a short backoff; if the
        // alarm turns up registered anyway, that counts as done.
        var delay: Duration = .milliseconds(250)
        for attempt in 1...Self.scheduleAttempts {
            do {
                _ = try await manager.schedule(id: alarm.id, configuration: configuration)
                return
            } catch {
                if (try? manager.alarms.contains { $0.id == alarm.id }) == true { return }
                if attempt == Self.scheduleAttempts { throw error }
                try await Task.sleep(for: delay)
                delay *= 2
            }
        }
    }

    /// Tries per alarm before a reconcile gives up (the next open retries).
    static let scheduleAttempts = 4

    func cancel(alarmID: UUID) async throws {
        try manager.cancel(id: alarmID)
    }
}
