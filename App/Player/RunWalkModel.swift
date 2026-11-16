import ActivityKit
import CoachCore
import Foundation
import Observation

/// Plays a run-walk (board M1-07): each segment counts down and moves on by
/// itself, the voice calls every change through headphones, and a Live
/// Activity mirrors the screen so the phone can stay locked. One control: Pause.
@MainActor
@Observable
final class RunWalkModel {
    let plan: RunWalkPlan
    private(set) var index = 0
    private(set) var endsAt: Date?
    private(set) var pausedRemaining: Int?
    private(set) var finished = false
    private(set) var log: SessionLog
    let voiceOn: Bool

    @ObservationIgnored private let voice: VoiceCuePlayer?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var activityID: String?

    init(plan: RunWalkPlan, programmeID: String, voiceCues: Bool, now: Date) {
        self.plan = plan
        self.log = SessionLog(programmeID: programmeID, sessionID: plan.sessionID, week: plan.week, startedAt: now)
        var voice: VoiceCuePlayer? = voiceCues ? VoiceCuePlayer() : nil
        if let player = voice {
            do { try player.beginHolding() } catch { voice = nil }
        }
        self.voice = voice
        self.voiceOn = voice != nil
    }

    var segment: RunWalkPlan.Segment? { plan.segments[safe: index] }
    var isPaused: Bool { pausedRemaining != nil }

    func begin() {
        guard endsAt == nil, !finished else { return }
        startSegment(index, remaining: plan.segments.first?.seconds ?? 0)
        startActivity()
    }

    func togglePause() {
        if let remaining = pausedRemaining {
            pausedRemaining = nil
            startSegment(index, remaining: remaining, announce: false)
        } else if let endsAt {
            ticker?.cancel()
            pausedRemaining = max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up)))
            self.endsAt = nil
        }
        updateActivity()
    }

    /// Ended early or finished: stop the clock, voice and lock-screen activity.
    func end() {
        ticker?.cancel()
        ticker = nil
        endActivity()
        voice?.endHolding()
    }

    func close(now: Date) -> SessionLog {
        if finished { log.finishedAt = now }
        end()
        return log
    }

    /// Seconds gone and to go, for the one small stats line.
    func elapsedAndRemaining(at date: Date) -> (gone: Int, toGo: Int) {
        let before = plan.segments.prefix(index).map(\.seconds).reduce(0, +)
        let current = segment?.seconds ?? 0
        let left = pausedRemaining ?? endsAt.map { max(0, Int($0.timeIntervalSince(date).rounded(.up))) } ?? 0
        let gone = before + (current - left)
        return (gone, plan.totalSeconds - gone)
    }

    // MARK: Flow

    private func startSegment(_ i: Int, remaining: Int, announce: Bool = true) {
        index = i
        let ends = Date.now.addingTimeInterval(TimeInterval(remaining))
        endsAt = ends
        if announce, let voice {
            let line = plan.cue(at: i)
            Task { await voice.announce(line) }
        }
        updateActivity()
        ticker?.cancel()
        ticker = Task { [weak self] in
            let delay = ends.timeIntervalSinceNow
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled, let self else { return }
            self.advance()
        }
    }

    private func advance() {
        let next = index + 1
        if plan.segments.indices.contains(next) {
            startSegment(next, remaining: plan.segments[next].seconds)
        } else {
            finished = true
            endsAt = nil
            if let voice {
                let line = plan.cue(at: next)
                Task { await voice.announce(line) }
            }
            endActivity()
        }
    }

    // MARK: Live Activity

    private var state: RunWalkAttributes.ContentState? {
        guard let segment else { return nil }
        let ends = endsAt ?? Date.now.addingTimeInterval(TimeInterval(pausedRemaining ?? 0))
        return RunWalkAttributes.ContentState(
            label: RunWalkFormat.label(segment.kind), isJog: segment.isJog, endsAt: ends,
            pausedRemaining: pausedRemaining, nextUp: RunWalkFormat.nextUp(plan, after: index),
            progress: RunWalkFormat.progress(plan, segment))
    }

    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, let state else { return }
        activityID = try? Activity.request(
            attributes: RunWalkAttributes(title: "\(plan.name) · Week \(plan.week)"),
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        ).id
    }

    private func updateActivity() {
        guard let id = activityID, let state else { return }
        Task {
            for live in Activity<RunWalkAttributes>.activities where live.id == id {
                await live.update(ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    private func endActivity() {
        guard let id = activityID else { return }
        activityID = nil
        Task {
            for live in Activity<RunWalkAttributes>.activities where live.id == id {
                await live.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

enum RunWalkFormat {
    static func label(_ kind: RunWalkPlan.Segment.Kind) -> String {
        switch kind {
        case .jog: "JOG"
        case .walk: "WALK"
        case .warmUp: "WARM-UP WALK"
        case .coolDown: "COOL-DOWN"
        }
    }

    static func nextUp(_ plan: RunWalkPlan, after index: Int) -> String {
        guard let next = plan.segments[safe: index + 1] else { return "Then done" }
        let word: String = switch next.kind {
        case .jog: "jog"
        case .walk, .warmUp: "walk"
        case .coolDown: "cool-down walk"
        }
        return "Then \(word) \(PlayerFormat.clock(next.seconds))"
    }

    static func progress(_ plan: RunWalkPlan, _ segment: RunWalkPlan.Segment) -> String {
        if let n = segment.interval { return "Interval \(n) of \(plan.repeats)" }
        return segment.kind == .warmUp ? "Warm-up" : "Cool-down"
    }
}
