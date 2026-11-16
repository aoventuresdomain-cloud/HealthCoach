import SwiftUI

/// Gate 0 scaffolding (board M0-11): one-tap tests for spikes S1, S1b and S3.
/// Hide behind Settings or delete before Gate 1 by setting `isEnabled` to false.
enum SpikeTests {
    static let isEnabled = true
}

struct SpikeTestsView: View {
    var alarms: any AlarmSpikeRunning = AlarmKitSpike.shared
    /// Starts the rest timer on appear; CI screenshots only (`-screenshot spikes-timer`).
    var autostartTimer = false

    @State private var timer = RestTimerSpike()
    @State private var alarmResult = "Not run yet."
    @State private var reconcileResult = "Checking…"
    @State private var settingAlarms = false

    var body: some View {
        List {
            Section {
                Button(settingAlarms ? "Setting alarms…" : "Set test alarms") {
                    Task { await setAlarms() }
                }
                .disabled(settingAlarms)
                ResultText(alarmResult)
            } header: {
                Text("S1 · Alarms")
            } footer: {
                Text("First alarm is 2 minutes ahead. Lock the phone, switch on Silent and a Focus, and wait.")
            }

            Section("S1b · Alarms after an update") {
                ResultText(reconcileResult)
                Button("Check again") { Task { await refreshReconcile() } }
            }

            Section {
                Button("Clear later test alarms", role: .destructive) {
                    Task { await clearLater() }
                }
            } footer: {
                Text("Removes the 13 test alarms set three weeks out. Use it if the real alarm planner isn't in by then.")
            }

            Section {
                if timer.isRunning {
                    Button("Cancel test timer", role: .destructive) { timer.cancel() }
                } else {
                    Button("Start test timer") { timer.start() }
                }
                ResultText(timer.status)
            } header: {
                Text("S3 · Rest timer")
            } footer: {
                Text("Play music through headphones, tap Start, then lock the phone. You should hear 3, 2, 1, go over ducked music after \(RestTimerSpike.restSeconds) seconds.")
            }
        }
        .navigationTitle("Spike tests")
        .task {
            await timer.endLeftovers()
            if autostartTimer { timer.start() }
            await refreshReconcile()
        }
    }

    private func setAlarms() async {
        settingAlarms = true
        defer { settingAlarms = false }
        do {
            alarmResult = Self.describe(try await alarms.setTestAlarms())
        } catch {
            alarmResult = "Failed: \(error.localizedDescription)"
        }
        await refreshReconcile()
    }

    private func clearLater() async {
        do {
            alarmResult = "Cleared later alarms. " + Self.describe(try await alarms.clearLaterTestAlarms())
        } catch {
            alarmResult = "Failed: \(error.localizedDescription)"
        }
    }

    private func refreshReconcile() async {
        reconcileResult = Self.describe(await alarms.reconcileStatus())
    }

    static func describe(_ summary: AlarmSpikeSummary) -> String {
        let noun = summary.count == 1 ? "alarm" : "alarms"
        guard let next = summary.next else { return "\(summary.count) \(noun) set." }
        return "\(summary.count) \(noun) set, next at \(next.formatted(date: .omitted, time: .shortened))."
    }

    static func describe(_ status: AlarmReconcileStatus) -> String {
        switch status {
        case .notYetRun: "⚠️ Alarm check hasn't run yet."
        case .allSet(let count): "All alarms set (\(count))."
        case .reSet(let missing, let total): "⚠️ \(missing) of \(total) alarms were missing and have been re-set."
        case .failed(let reason): "⚠️ Alarm check failed: \(reason)"
        }
    }
}

private struct ResultText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Result: \(text)")
    }
}

#Preview {
    NavigationStack { SpikeTestsView() }
}
