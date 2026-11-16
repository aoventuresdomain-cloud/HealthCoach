import Foundation

/// Seam between the Spike tests screen (M0-11, iOS Interface Engineer) and the
/// AlarmKit spikes S1/S1b (M0-04, M0-05, Planner Engineer). The screen only
/// formats what these return; all AlarmKit and reconcile logic lives behind it.
@MainActor
protocol AlarmSpikeRunning {
    /// Asks for alarm permission if needed, then registers the 14 test alarms,
    /// the first 2 minutes from now.
    func setTestAlarms() async throws -> AlarmSpikeSummary
    /// Result of the on-open reconcile (registered alarms vs the plan).
    func reconcileStatus() async -> AlarmReconcileStatus
}

struct AlarmSpikeSummary: Equatable {
    let count: Int
    let next: Date?
}

enum AlarmReconcileStatus: Equatable {
    case notYetRun
    case allSet(count: Int)
    case reSet(missing: Int, total: Int)
    case failed(String)
}

/// Stands in until M0-04 lands, so the screen builds and can be walked.
struct PlaceholderAlarmSpike: AlarmSpikeRunning {
    struct NotBuilt: LocalizedError {
        var errorDescription: String? { "Alarm test not built yet (board M0-04)." }
    }

    func setTestAlarms() async throws -> AlarmSpikeSummary { throw NotBuilt() }
    func reconcileStatus() async -> AlarmReconcileStatus { .notYetRun }
}
