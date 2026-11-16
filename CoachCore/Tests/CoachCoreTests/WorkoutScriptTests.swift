import Foundation
import Testing
@testable import CoachCore

@Suite struct WorkoutScriptTests {
    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    @Test func upperAWeekOneFollowsTheData() throws {
        let programme = try phase1()
        let script = try #require(WorkoutScript.make(sessionID: "upper-a", programme: programme, week: 1))
        guard case let .strength(session) = programme.sessions["upper-a"] else { Issue.record("upper-a"); return }
        let items = session.blocks.flatMap(\.items).filter { $0.sets[0] > 0 }
        #expect(script.exerciseCount == items.count)
        #expect(script.sets.count == items.map { $0.sets[0] }.reduce(0, +))
        #expect(script.warmUp.count == session.warmUp.count)
        #expect(script.warmUpSecondsPerMove == session.warmUpMinutes * 60 / session.warmUp.count)

        let first = try #require(script.sets.first)
        #expect(first.exercise == "dumbbell-bench-press")
        #expect(first.kind == .reps(target: 8))
        #expect(first.kg == 10)
        #expect(first.restSeconds == session.blocks[0].restSeconds)
        #expect(first.cue == programme.effort[0].cue)
        #expect(script.sets.last?.restSeconds == 0)
    }

    @Test func setKindsComeFromTheItems() throws {
        let script = try #require(WorkoutScript.make(sessionID: "upper-a", programme: phase1(), week: 1))
        let kinds = Dictionary(script.sets.map { ($0.exercise, $0.kind) }, uniquingKeysWith: { a, _ in a })
        #expect(kinds["dumbbell-one-arm-row"] == .perSide(target: 8))
        #expect(kinds["negative-pull-up"] == .negatives(reps: 3, lowerSeconds: 5))
        #expect(kinds["plank"] == .hold(seconds: 20))
    }

    @Test func loadsOverrideStartWeights() throws {
        let script = try #require(WorkoutScript.make(sessionID: "upper-a", programme: phase1(), week: 1,
                                                      loads: ["dumbbell-bench-press": 12]))
        #expect(script.sets.first?.kg == 12)
    }

    @Test func notAStrengthSession() throws {
        #expect(WorkoutScript.make(sessionID: "run-1", programme: try phase1(), week: 1) == nil)
    }

    @Test func countedSetsLogAsTheyWere() throws {
        let script = try #require(WorkoutScript.make(sessionID: "upper-a", programme: phase1(), week: 1))
        let bench = try #require(script.sets.first)
        #expect(bench.prescribedLog() == SetLog(exercise: "dumbbell-bench-press", setIndex: 0, reps: 8, kg: 10, asPrescribed: true))
        #expect(bench.log(counted: 7).asPrescribed == false)
        #expect(bench.log(counted: 7).reps == 7)
        #expect(bench.log(counted: 9).asPrescribed)
        let plank = try #require(script.sets.first { $0.exercise == "plank" })
        #expect(plank.log(counted: 20) == SetLog(exercise: "plank", setIndex: 0, seconds: 20, asPrescribed: true))
    }
}
