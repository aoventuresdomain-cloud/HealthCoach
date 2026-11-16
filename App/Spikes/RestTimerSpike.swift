import ActivityKit
import Foundation
import Observation

/// Drives the 90-second rest-timer spike: Live Activity on the lock screen and
/// Dynamic Island, voice cues at the end, clean teardown (S3, board M0-06).
@MainActor
@Observable
final class RestTimerSpike {
    static let restSeconds = 90

    private(set) var status = "Not run yet."
    private(set) var isRunning = false

    @ObservationIgnored private let voice = VoiceCuePlayer()
    @ObservationIgnored private var activity: Activity<RestTimerAttributes>?
    @ObservationIgnored private var run: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Live Activities are off. Turn them on in Settings › HealthCoach."
            return
        }

        let endsAt = Date.now.addingTimeInterval(TimeInterval(Self.restSeconds))
        do {
            try voice.beginHolding()
            let state = RestTimerAttributes.ContentState(endsAt: endsAt, nextUp: "Spike test: lock the phone now")
            activity = try Activity.request(
                attributes: RestTimerAttributes(title: "Rest"),
                content: ActivityContent(state: state, staleDate: endsAt),
                pushType: nil
            )
        } catch {
            voice.endHolding()
            status = "Couldn't start: \(error.localizedDescription)"
            return
        }

        isRunning = true
        status = "Running: \(Self.restSeconds) s rest, ends at \(endsAt.formatted(date: .omitted, time: .standard)). Lock the phone."
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
            try await sleep(until: endsAt.addingTimeInterval(-3.5))
            voice.duckOthers()
            for (offset, word) in [(-3.0, "3"), (-2.0, "2"), (-1.0, "1")] {
                try await sleep(until: endsAt.addingTimeInterval(offset))
                await voice.say(word)
            }
            try await sleep(until: endsAt)
            await voice.say("Go")
            await finish(message: "Finished: \(Self.restSeconds) s rest, cues played, lock screen cleared.")
        } catch {
            // Cancelled; cancel() handles teardown.
        }
    }

    private func finish(message: String) async {
        if let activity {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
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
