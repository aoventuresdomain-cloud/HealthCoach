import ActivityKit
import Foundation
import Observation

/// The rest between sets (board M1-06): a countdown that moves on by itself
/// at zero, mirrored on the lock screen and Dynamic Island by the M0-06 Live
/// Activity, with "3, 2, 1, go" in the headphones. "+30 s" extends it; "Next"
/// skips it. The activity always ends with the rest, so nothing lingers.
@MainActor
@Observable
final class RestClock {
    private(set) var endsAt: Date?
    private(set) var totalSeconds = 0

    @ObservationIgnored private var activityID: String?
    @ObservationIgnored private var countdown: Task<Void, Never>?
    @ObservationIgnored private var onFinish: (() -> Void)?
    @ObservationIgnored private var nextUp = ""
    @ObservationIgnored private let voice: VoiceCuePlayer?

    /// `voice` nil = no spoken cues (the owner turned them off, or no audio).
    init(voice: VoiceCuePlayer?) {
        self.voice = voice
    }

    var isRunning: Bool { endsAt != nil }

    func start(seconds: Int, nextUp: String, onFinish: @escaping () -> Void) {
        stop()
        let ends = Date.now.addingTimeInterval(TimeInterval(seconds))
        endsAt = ends
        totalSeconds = seconds
        self.nextUp = nextUp
        self.onFinish = onFinish
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let state = RestTimerAttributes.ContentState(endsAt: ends, nextUp: nextUp)
            activityID = try? Activity.request(
                attributes: RestTimerAttributes(title: "Rest"),
                content: ActivityContent(state: state, staleDate: ends),
                pushType: nil
            ).id
        }
        schedule(until: ends)
    }

    func extend(by seconds: Int) {
        guard let current = endsAt else { return }
        let ends = current.addingTimeInterval(TimeInterval(seconds))
        endsAt = ends
        totalSeconds += seconds
        if let activityID {
            let state = RestTimerAttributes.ContentState(endsAt: ends, nextUp: nextUp)
            Task {
                for live in Activity<RestTimerAttributes>.activities where live.id == activityID {
                    await live.update(ActivityContent(state: state, staleDate: ends))
                }
            }
        }
        schedule(until: ends)
    }

    /// "Next": end the rest now and move on.
    func skip() {
        guard isRunning else { return }
        finish()
    }

    /// Ends the rest without moving on (the session was ended).
    func stop() {
        countdown?.cancel()
        countdown = nil
        onFinish = nil
        endActivity()
        endsAt = nil
    }

    private func schedule(until ends: Date) {
        countdown?.cancel()
        countdown = Task { [weak self] in
            do {
                if let voice = self?.voice {
                    try await Self.sleep(until: ends.addingTimeInterval(-3.5))
                    voice.duckOthers()
                    for (offset, word) in [(-3.0, "3"), (-2.0, "2"), (-1.0, "1")] {
                        try await Self.sleep(until: ends.addingTimeInterval(offset))
                        await voice.say(word)
                    }
                    try await Self.sleep(until: ends)
                    await voice.say("Go")
                    voice.mixAgain()
                } else {
                    try await Self.sleep(until: ends)
                }
                self?.finish()
            } catch {
                // Cancelled by extend, skip or stop.
            }
        }
    }

    private func finish() {
        countdown?.cancel()
        countdown = nil
        let done = onFinish
        onFinish = nil
        endActivity()
        endsAt = nil
        done?()
    }

    private func endActivity() {
        guard let id = activityID else { return }
        activityID = nil
        Task {
            for live in Activity<RestTimerAttributes>.activities where live.id == id {
                await live.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func sleep(until date: Date) async throws {
        let delay = date.timeIntervalSinceNow
        if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
        try Task.checkCancellation()
    }
}
