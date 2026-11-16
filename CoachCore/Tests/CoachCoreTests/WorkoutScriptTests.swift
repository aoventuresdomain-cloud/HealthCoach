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

    @Test func everyPhaseOneBlockSetsItsOwnRest() throws {
        let programme = try phase1()
        var checked = 0
        for (id, session) in programme.sessions {
            guard case let .strength(strength) = session else { continue }
            for block in strength.blocks {
                #expect(block.restSeconds > 0, "\(id) \(block.label) has no rest")
                checked += 1
            }
            // Each set rests for its own block's value, never the fallback.
            for week in 1...programme.weeks {
                let script = try #require(WorkoutScript.make(sessionID: id, programme: programme, week: week))
                let blockRests = Set(strength.blocks.map(\.restSeconds))
                for step in script.sets.dropLast() {
                    #expect(blockRests.contains(step.restSeconds), "\(id) week \(week): \(step.restSeconds) s")
                }
            }
        }
        #expect(checked > 0)
    }

    @Test func missingRestFallsBackToNinetySeconds() throws {
        let block = StrengthSession.Block(label: "A", restSeconds: 0, items: [])
        #expect(WorkoutScript.restSeconds(for: block) == 90)
        #expect(WorkoutScript.restSeconds(for: StrengthSession.Block(label: "B", restSeconds: 45, items: [])) == 45)
    }

    @Test func setKindsComeFromTheItems() throws {
        let script = try #require(WorkoutScript.make(sessionID: "upper-a", programme: phase1(), week: 1))
        let kinds = Dictionary(script.sets.map { ($0.exercise, $0.kind) }, uniquingKeysWith: { a, _ in a })
        #expect(kinds["dumbbell-one-arm-row"] == .perSide(target: 8))
        #expect(kinds["negative-pull-up"] == .negatives(reps: 3, lowerSeconds: 5))
        #expect(kinds["plank"] == .hold(seconds: 20))
    }

    @Test func targetsAndWeightsComeFromThePrescription() throws {
        let programme = try phase1()
        // Last Upper A: every bench press set done as prescribed at 10 kg.
        var log = SessionLog(programmeID: "phase-1", sessionID: "upper-a", week: 1,
                             startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        log.sets = (0..<3).map { SetLog(exercise: "dumbbell-bench-press", setIndex: $0, reps: 8, kg: 10, asPrescribed: true) }
        let script = try #require(WorkoutScript.make(sessionID: "upper-a", programme: programme, week: 2, history: [log]))

        guard case let .strength(session) = programme.sessions["upper-a"] else { Issue.record("upper-a"); return }
        let bench = try #require(session.blocks.flatMap(\.items).first { $0.exercise == "dumbbell-bench-press" })
        let expected = try #require(programme.prescription(for: bench, week: 2, history: [log]))
        let first = try #require(script.sets.first)
        #expect(first.kind == .reps(target: try #require(expected.reps)))
        #expect(first.kg == expected.kg)
        #expect(first.slowTempo == expected.slowTempo)
        #expect(script.sets.filter { $0.exercise == "dumbbell-bench-press" }.count == expected.sets)
    }

    @Test func pushUpsSwapToBenchPressWhenTheFirstSetFallsShort() throws {
        let script = try #require(WorkoutScript.make(sessionID: "full-body", programme: phase1(), week: 2))
        let index = try #require(script.sets.firstIndex { $0.exercise == "push-up" })
        let swap = try #require(script.sets[index].swap)
        #expect(swap.exercise == "dumbbell-bench-press")
        #expect(swap.whenFirstSetRepsBelow == 6)
        #expect(script.sets[index + 1].swap == nil)

        let swapped = script.swappingRemainingSets(after: index)
        let rest = swapped.sets.filter { $0.exerciseNumber == script.sets[index].exerciseNumber }
        #expect(rest.first?.exercise == "push-up")
        #expect(rest.dropFirst().allSatisfy { $0.exercise == "dumbbell-bench-press" && $0.kg == swap.kg })
        #expect(swapped.sets.count == script.sets.count)
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
