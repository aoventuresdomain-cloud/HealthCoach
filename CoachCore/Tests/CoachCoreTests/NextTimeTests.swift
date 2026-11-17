import Foundation
import Testing
@testable import CoachCore

/// QA-13: the done screen shows next time's loads, from the progression rules.
@Suite struct NextTimeTests {
    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    /// Upper A week 1, every set done as prescribed.
    private func finishedUpperA(_ programme: Programme) throws -> SessionLog {
        let script = try #require(WorkoutScript.make(sessionID: "upper-a", programme: programme, week: 1))
        var log = SessionLog(programmeID: "phase-1", sessionID: "upper-a", week: 1,
                             startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        log.sets = script.sets.map { $0.prescribedLog() }
        return log
    }

    @Test func oneLinePerExerciseInSessionOrder() throws {
        let programme = try phase1()
        let log = try finishedUpperA(programme)
        let lines = NextTime.lines(sessionID: "upper-a", programme: programme, week: 1, history: [log])
        let week2 = try #require(WorkoutScript.make(sessionID: "upper-a", programme: programme, week: 2, history: [log]))
        var order: [String] = []
        for step in week2.sets where !order.contains(step.exercise) { order.append(step.exercise) }
        #expect(lines.map(\.exercise) == order)
    }

    @Test func linesMatchNextWeeksPrescription() throws {
        let programme = try phase1()
        let log = try finishedUpperA(programme)
        let lines = NextTime.lines(sessionID: "upper-a", programme: programme, week: 1, history: [log])
        guard case let .strength(session) = programme.sessions["upper-a"] else { Issue.record("upper-a"); return }
        let bench = try #require(session.blocks.flatMap(\.items).first { $0.exercise == "dumbbell-bench-press" })
        let expected = try #require(programme.prescription(for: bench, week: 2, history: [log]))
        let line = try #require(lines.first { $0.exercise == "dumbbell-bench-press" })
        let reps = try #require(expected.reps)
        let kg = try #require(expected.kg)
        #expect(line.text.hasPrefix("\(expected.sets) × \(reps) @ \(PlayerCues.kilos(kg)) kg"), "\(line.text)")
        // Every set hit the target, so the bench moved on from week 1's 8 reps at 10 kg.
        #expect(expected.step != .start)
    }

    @Test func formatsEachKind() {
        func step(_ kind: WorkoutScript.SetStep.Kind, kg: Double?, slow: Bool = false) -> WorkoutScript.SetStep {
            WorkoutScript.SetStep(exercise: "x", kind: kind, kg: kg, setIndex: 0, setCount: 2, exerciseNumber: 1,
                                  repsInReserve: nil, cue: nil, note: nil, restSeconds: 60, slowTempo: slow,
                                  atDumbbellLimit: false, swap: nil)
        }
        #expect(NextTime.text(step(.reps(target: 9), kg: 10)) == "2 × 9 @ 10 kg")
        #expect(NextTime.text(step(.reps(target: 10), kg: 7.5, slow: true)) == "2 × 10 @ 7.5 kg · slow lower")
        #expect(NextTime.text(step(.perSide(target: 10), kg: 6)) == "2 × 10 each side @ 6 kg")
        #expect(NextTime.text(step(.hold(seconds: 25), kg: nil)) == "2 × 25 s")
    }

    /// UI-9: up only when next time's load beats today's heaviest set; never for bodyweight.
    @Test func loadUpOnlyWhenHeavier() throws {
        let programme = try phase1()
        let log = try finishedUpperA(programme)
        let lines = NextTime.lines(sessionID: "upper-a", programme: programme, week: 1, history: [log])
        let week2 = try #require(WorkoutScript.make(sessionID: "upper-a", programme: programme, week: 2, history: [log]))
        for line in lines {
            let next = week2.sets.first { $0.exercise == line.exercise }?.kg
            let today = log.sets.filter { $0.exercise == line.exercise }.compactMap(\.kg).max()
            let expected = next.map { n in today.map { n > $0 } ?? false } ?? false
            #expect(line.loadUp == expected, "\(line.exercise)")
        }
        #expect(NextTime.lines(sessionID: "upper-a", programme: programme, week: 1, history: []).allSatisfy { !$0.loadUp })
    }

    /// UI-12: an increase is any of heavier, an extra set or a higher target;
    /// every load-up is an increase, and nothing logged means no increase.
    @Test func increaseCoversLoadSetsAndTarget() throws {
        let programme = try phase1()
        let log = try finishedUpperA(programme)
        let lines = NextTime.lines(sessionID: "upper-a", programme: programme, week: 1, history: [log])
        let week2 = try #require(WorkoutScript.make(sessionID: "upper-a", programme: programme, week: 2, history: [log]))
        for line in lines {
            let next = try #require(week2.sets.first { $0.exercise == line.exercise })
            let done = log.sets.filter { $0.exercise == line.exercise }
            let lighter = done.compactMap(\.kg).max().map { (next.kg ?? 0) < $0 } ?? false
            #expect(line.increase == (line.loadUp || (!lighter && NextTime.more(next, than: done))), "\(line.exercise)")
            if line.loadUp { #expect(line.increase) }
        }
        // Week 1 → 2 moves at least one lift on, so the done screen is never empty.
        #expect(lines.contains { $0.increase })
        #expect(NextTime.lines(sessionID: "upper-a", programme: programme, week: 1, history: []).allSatisfy { !$0.increase })
    }

    @Test func moreSpotsSetsAndTargets() {
        func step(_ kind: WorkoutScript.SetStep.Kind, sets: Int) -> WorkoutScript.SetStep {
            WorkoutScript.SetStep(exercise: "x", kind: kind, kg: 10, setIndex: 0, setCount: sets, exerciseNumber: 1,
                                  repsInReserve: nil, cue: nil, note: nil, restSeconds: 60, slowTempo: false,
                                  atDumbbellLimit: false, swap: nil)
        }
        let twoByEight = [0, 1].map { SetLog(exercise: "x", setIndex: $0, reps: 8, kg: 10, asPrescribed: true) }
        #expect(NextTime.more(step(.reps(target: 8), sets: 3), than: twoByEight))
        #expect(NextTime.more(step(.reps(target: 9), sets: 2), than: twoByEight))
        #expect(!NextTime.more(step(.reps(target: 8), sets: 2), than: twoByEight))
        #expect(!NextTime.more(step(.reps(target: 8), sets: 3), than: []))
        let holds = [0, 1].map { SetLog(exercise: "x", setIndex: $0, seconds: 20, asPrescribed: true) }
        #expect(NextTime.more(step(.hold(seconds: 25), sets: 2), than: holds))
    }
}
