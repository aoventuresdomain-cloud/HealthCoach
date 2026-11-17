import CoachCore
import ActivityKit
import Foundation
import Observation

/// Drives the 90-second rest-timer spike: Live Activity on the lock screen and
/// Dynamic Island, voice cues at the end, clean teardown (S3, board M0-06).
@MainActor
@Observable
final class RestTimerSpike {
    static let defaultRestSeconds = 90

    /// Length of the test rest. Screenshot runs pass a shorter one (`-restSeconds`).
    let restSeconds: Int

    private(set) var status = "Not run yet."
    private(set) var isRunning = false

    @ObservationIgnored private let voice = VoiceCuePlayer()
    /// Held by id, not as an `Activity`: Activity isn't Sendable, so ending a
    /// stored one from the main actor fails Swift 6 checking ("sending
    /// 'activity' risks causing data races"). Looked up fresh when ending.
    @ObservationIgnored private var activityID: String?
    @ObservationIgnored private var run: Task<Void, Never>?
    @ObservationIgnored private var voiceOn = false

    init(restSeconds: Int = RestTimerSpike.defaultRestSeconds) {
        // At least 5 s, so the 3-2-1 cues fit.
        self.restSeconds = max(5, restSeconds)
    }

    func start() {
        guard !isRunning else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Live Activities are off. Turn them on in Settings › HealthCoach."
            return
        }

        let endsAt = Date.now.addingTimeInterval(TimeInterval(restSeconds))
        // A timer without voice beats no timer (e.g. a CI simulator with no audio output).
        var voiceProblem: String?
        do {
            try voice.beginHolding()
        } catch {
            voiceProblem = error.localizedDescription
        }
        voiceOn = voiceProblem == nil

        do {
            let state = RestTimerAttributes.ContentState(endsAt: endsAt, nextUp: "Spike test: lock the phone now")
            activityID = try Activity.request(
                attributes: RestTimerAttributes(title: "Rest"),
                content: ActivityContent(state: state, staleDate: endsAt),
                pushType: nil
            ).id
        } catch {
            voice.endHolding()
            status = "Couldn't start: \(error.localizedDescription)"
            return
        }

        isRunning = true
        status = "Running: \(restSeconds) s rest, ends at \(endsAt.formatted(date: .omitted, time: .standard)). Lock the phone."
        if let voiceProblem { status += " Voice cues off: \(voiceProblem)" }
        run = Task { await self.countdown(to: endsAt) }
    }

    func cancel() {
        guard isRunning else { return }
        run?.cancel()
        run = nil
        Task { await finish(message: "Cancelled. Lock screen cleared.") }
    }

    /// Ends any rest-timer activity left behind (for example, if the app was
    /// killed mid-rest), so nothing lingers on the lock screen.
    func endLeftovers() async {
        guard !isRunning else { return }
        for leftover in Activity<RestTimerAttributes>.activities {
            await leftover.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func countdown(to endsAt: Date) async {
        do {
            // Cues land on the last three seconds, then "go" at zero.
            if voiceOn {
                try await sleep(until: endsAt.addingTimeInterval(-3.5))
                voice.duckOthers()
                for (offset, word) in [(-3.0, "3"), (-2.0, "2"), (-1.0, "1")] {
                    try await sleep(until: endsAt.addingTimeInterval(offset))
                    await voice.say(word)
                }
            }
            try await sleep(until: endsAt)
            if voiceOn { await voice.say("Go") }
            let cues = voiceOn ? "cues played" : "no voice cues"
            await finish(message: "Finished: \(restSeconds) s rest, \(cues), lock screen cleared.")
        } catch {
            // Cancelled; cancel() handles teardown.
        }
    }

    private func finish(message: String) async {
        if let activityID {
            for live in Activity<RestTimerAttributes>.activities where live.id == activityID {
                await live.end(nil, dismissalPolicy: .immediate)
            }
        }
        activityID = nil
        voice.endHolding()
        isRunning = false
        status = message
    }

    private func sleep(until date: Date) async throws {
        let delay = date.timeIntervalSinceNow
        if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
        try Task.checkCancellation()
    }
}
