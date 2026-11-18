import CoachCore
import SwiftUI

/// What "Start" on Today opens, by session kind.
struct SessionLaunch: Identifiable {
    enum Player {
        case strength(WorkoutPlayerModel)
        case runWalk(RunWalkModel)
        case walk(name: String, minutes: Int?, log: SessionLog)
    }

    let id = UUID()
    let player: Player

    @MainActor
    static func make(slot: DayPlan.SessionSlot, week: Int, recovery: RecoveryCheck,
                     content: ContentLibrary, programme: Programme, profile: Profile,
                     history: [SessionLog]) -> SessionLaunch? {
        let now = AppClock.now()
        let voiceCues = profile.training.voiceCues
        // Strength UI tests run without speech so the warm-up and holds keep a
        // steady pace; run-walk keeps its cues (a failed audio route turns them off).
        let strengthVoice = voiceCues && !LaunchOptions.current.isUITest
        switch slot.session {
        case .strength:
            // Imported loads (M4-02) hold until that exercise is next logged.
            guard let script = WorkoutScript.make(sessionID: slot.id, programme: programme, week: week, history: history,
                                                  blocks: CoachBlockStore().all, on: now,
                                                  calendar: .coach) else { return nil }
            return SessionLaunch(player: .strength(WorkoutPlayerModel(
                script: script, catalogue: content.exercises, programmeID: programme.id,
                recovery: recovery, voiceCues: strengthVoice, now: now,
                lastTime: LastTime.lines(for: script, history: history),
                nextTime: { log in
                    NextTime.lines(sessionID: slot.id, programme: programme, week: week, history: history + [log])
                })))
        case let .runWalk(run):
            // N8: after 10+ days without a run, repeat the previous week's (two back after 21+).
            let runWeek = programme.runWeek(week, history: history, on: now, calendar: .coach)
            guard let plan = RunWalkPlan.make(sessionID: slot.id, session: run, week: runWeek) else { return nil }
            return SessionLaunch(player: .runWalk(RunWalkModel(
                plan: plan, programmeID: programme.id, voiceCues: voiceCues, now: now)))
        case .walk, .circuit:
            let log = SessionLog(programmeID: programme.id, sessionID: slot.id, week: week, startedAt: now)
            return SessionLaunch(player: .walk(name: slot.name, minutes: slot.minutes, log: log))
        }
    }

    @MainActor @ViewBuilder
    func view(onClose: @escaping (SessionLog) -> Void) -> some View {
        switch player {
        case let .strength(model):
            WorkoutPlayerView(model: model, onClose: onClose)
        case let .runWalk(model):
            RunWalkView(model: model, onClose: onClose)
        case let .walk(name, minutes, log):
            WalkView(name: name, minutes: minutes, log: log, onClose: onClose)
        }
    }
}
