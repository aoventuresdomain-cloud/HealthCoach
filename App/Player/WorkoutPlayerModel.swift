import CoachCore
import Foundation
import Observation

/// Drives a strength session (board M1-06): warm-up (voice-led, auto-advancing)
/// → each set ("Done" logs it as prescribed, or the tap count if used) → rest
/// (moves on by itself) → … → done. The only path a normal session needs is
/// "Next" and "Done".
@MainActor
@Observable
final class WorkoutPlayerModel {
    enum Phase: Equatable {
        case warmUp(Int)
        case set(Int)
        case rest(next: Int)
        case done
    }

    enum Side: Equatable { case left, right }

    /// Changes only when an autoSwap switches the rest of an item's sets.
    private(set) var script: WorkoutScript
    let catalogue: ExerciseCatalogue
    private(set) var phase: Phase
    /// Only for one-side-at-a-time sets.
    private(set) var side: Side?
    /// Tap counter for the current set (or side); 0 = unused.
    private(set) var count = 0
    /// Seconds held so far in a timed hold.
    private(set) var held = 0
    /// True during the "get in position" lead-in before a hold.
    private(set) var gettingReady = false
    private(set) var log: SessionLog
    let rest: RestClock

    @ObservationIgnored private let voice: VoiceCuePlayer?
    @ObservationIgnored private var stepTask: Task<Void, Never>?
    @ObservationIgnored private var leftCount = 0

    /// Lead-in before a hold starts counting.
    static let holdLeadInSeconds = 5

    init(script: WorkoutScript, catalogue: ExerciseCatalogue, programmeID: String,
         recovery: RecoveryCheck, voiceCues: Bool, now: Date) {
        self.script = script
        self.catalogue = catalogue
        var voice: VoiceCuePlayer? = voiceCues ? VoiceCuePlayer() : nil
        do { try voice?.beginHolding() } catch {
            voice = nil // No audio output: spoken cues off, the session still runs.
        }
        self.voice = voice
        self.rest = RestClock(voice: voice)
        self.log = SessionLog(programmeID: programmeID, sessionID: script.sessionID, week: script.week,
                              startedAt: now, recovery: recovery)
        self.phase = script.warmUp.isEmpty ? (script.sets.isEmpty ? .done : .set(0)) : .warmUp(0)
    }

    // MARK: Reading

    func exercise(_ id: String) -> Exercise? { catalogue.exercise(id) }
    func name(_ id: String) -> String { catalogue.exercise(id)?.name ?? id }

    var currentSet: WorkoutScript.SetStep? {
        switch phase {
        case let .set(i): script.sets[safe: i]
        case let .rest(next): script.sets[safe: next]
        default: nil
        }
    }

    /// 1-based exercise number for the progress bar (0 during warm-up).
    var exerciseNumber: Int {
        switch phase {
        case .warmUp: 0
        case let .set(i): script.sets[safe: i]?.exerciseNumber ?? 0
        case let .rest(next): (script.sets[safe: next]?.exerciseNumber ?? 1) - 1
        case .done: script.exerciseCount
        }
    }

    // MARK: Lifecycle

    /// Call once the player is on screen.
    func begin() {
        enter(phase)
    }

    /// End (✕) confirmed: stop everything; the log is kept unfinished.
    func end() {
        stepTask?.cancel()
        rest.stop()
        voice?.endHolding()
    }

    // MARK: Actions

    /// "Next": skip the rest of a warm-up move, or the rest.
    func next() {
        switch phase {
        case let .warmUp(i): advanceWarmUp(from: i)
        case .rest: rest.skip()
        case .set, .done: break
        }
    }

    /// The tap counter tile.
    func tapCount() {
        guard case .set = phase else { return }
        count += 1
    }

    /// "Done" on a set.
    func done() {
        guard case let .set(i) = phase, let step = script.sets[safe: i] else { return }
        stepTask?.cancel()
        if case .perSide = step.kind, side == .left {
            leftCount = count
            count = 0
            side = .right
            Task { await voice?.announce("Switch sides") }
            return
        }
        log.sets.append(entry(for: step))
        // autoSwap: a short first set (counted) switches the item's remaining sets, without asking.
        if let swap = step.swap, count > 0, count < swap.whenFirstSetRepsBelow {
            script = script.swappingRemainingSets(after: i)
            let to = name(swap.exercise)
            Task { await voice?.announce("Switching to \(to) for the next sets") }
        }
        afterSet(i)
    }

    /// "Something was different" edits on the done screen.
    func replaceSets(_ sets: [SetLog]) {
        log.sets = sets
    }

    func finish(now: Date) -> SessionLog {
        log.finishedAt = now
        end()
        return log
    }

    // MARK: Flow

    private func entry(for step: WorkoutScript.SetStep) -> SetLog {
        switch step.kind {
        case .hold:
            return held >= Self.target(step) || held == 0 ? step.prescribedLog() : step.log(counted: held)
        case .perSide:
            // Both sides counted: the weaker side is what was done.
            let counts = [leftCount, count].filter { $0 > 0 }
            return counts.isEmpty ? step.prescribedLog() : step.log(counted: counts.min()!)
        case .reps, .negatives:
            return count == 0 ? step.prescribedLog() : step.log(counted: count)
        }
    }

    private static func target(_ step: WorkoutScript.SetStep) -> Int {
        if case let .hold(seconds) = step.kind { return seconds }
        return 0
    }

    private func afterSet(_ i: Int) {
        guard let step = script.sets[safe: i] else { return }
        if step.restSeconds > 0, script.sets.indices.contains(i + 1) {
            let upcoming = script.sets[i + 1]
            phase = .rest(next: i + 1)
            rest.start(seconds: step.restSeconds, nextUp: nextUpLine(upcoming),
                       headsUp: spokenNextUp(upcoming)) { [weak self] in
                self?.enter(.set(i + 1))
            }
        } else if script.sets.indices.contains(i + 1) {
            enter(.set(i + 1))
        } else {
            phase = .done
            Task { await voice?.announce("Session done") }
        }
    }

    private func advanceWarmUp(from i: Int) {
        stepTask?.cancel()
        if script.warmUp.indices.contains(i + 1) {
            enter(.warmUp(i + 1))
        } else {
            enter(script.sets.isEmpty ? .done : .set(0))
        }
    }

    private func enter(_ next: Phase) {
        stepTask?.cancel()
        phase = next
        count = 0
        held = 0
        gettingReady = false
        switch next {
        case let .warmUp(i):
            let move = script.warmUp[i]
            let seconds = script.warmUpSecondsPerMove
            stepTask = Task { [weak self] in
                guard let self else { return }
                await self.voice?.announce(i == 0 ? "Warm-up. \(self.name(move.exercise))" : self.name(move.exercise))
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled, self.phase == .warmUp(i) else { return }
                self.advanceWarmUp(from: i)
            }
        case let .set(i):
            let step = script.sets[i]
            if case .perSide = step.kind { side = .left } else { side = nil }
            leftCount = 0
            switch step.kind {
            case let .hold(seconds):
                runHold(index: i, seconds: seconds)
            case let .negatives(reps, lower):
                runNegatives(index: i, reps: reps, lowerSeconds: lower)
            case .reps, .perSide:
                if step.setIndex == 0 {
                    Task { await voice?.announce(self.name(step.exercise)) }
                }
            }
        case .rest, .done:
            break
        }
    }

    /// "Get in position… hold", then the countdown; the rest starts at zero.
    private func runHold(index i: Int, seconds: Int) {
        gettingReady = true
        stepTask = Task { [weak self] in
            guard let self else { return }
            await self.voice?.announce("Get in position")
            try? await Task.sleep(for: .seconds(Self.holdLeadInSeconds))
            guard !Task.isCancelled, self.phase == .set(i) else { return }
            self.gettingReady = false
            await self.voice?.announce("Hold")
            for second in 1...max(seconds, 1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, self.phase == .set(i) else { return }
                self.held = second
            }
            self.done()
        }
    }

    /// Paces each lowering by voice: "Lower… 2… 3…", then "up".
    private func runNegatives(index i: Int, reps: Int, lowerSeconds: Int) {
        guard let voice else { return }
        stepTask = Task { [weak self] in
            for _ in 0..<reps {
                await voice.announce("Lower")
                for second in 2...max(lowerSeconds, 2) {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled, self?.phase == .set(i) else { return }
                    await voice.say("\(second)")
                }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, self?.phase == .set(i) else { return }
                await voice.say("Step up")
                try? await Task.sleep(for: .seconds(2))
            }
            voice.mixAgain()
        }
    }

    /// The 10-second heads-up, as the board words it:
    /// "10 seconds. Next, one-arm row, 12 kilos."
    private func spokenNextUp(_ step: WorkoutScript.SetStep) -> String {
        let load = step.kg.map { ", \(PlayerFormat.kg($0)) kilos" } ?? ""
        return "\(Int(RestClock.headsUpSeconds)) seconds. Next, \(name(step.exercise))\(load)."
    }

    private func nextUpLine(_ step: WorkoutScript.SetStep) -> String {
        let load = step.kg.map { " · dial to \(PlayerFormat.kg($0)) kg" } ?? ""
        return "Next: \(name(step.exercise)), set \(step.setIndex + 1)\(load)"
    }
}

enum PlayerFormat {
    static func kg(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(0...1)))
    }

    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
