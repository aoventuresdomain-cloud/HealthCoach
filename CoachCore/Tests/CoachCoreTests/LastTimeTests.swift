import Foundation
import Testing
@testable import CoachCore

/// C6: "last time → today" on each lift.
@Suite struct LastTimeTests {
    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    private func step(_ kind: WorkoutScript.SetStep.Kind, kg: Double?) -> WorkoutScript.SetStep {
        WorkoutScript.SetStep(exercise: "x", kind: kind, kg: kg, setIndex: 0, setCount: 3, exerciseNumber: 1,
                              repsInReserve: nil, cue: nil, note: nil, restSeconds: 60, slowTempo: false,
                              atDumbbellLimit: false, swap: nil)
    }

    private func log(_ day: TimeInterval, _ sets: [SetLog]) -> SessionLog {
        var log = SessionLog(programmeID: "phase-1", sessionID: "s", week: 1,
                             startedAt: Date(timeIntervalSince1970: 1_800_000_000 + day * 86_400))
        log.sets = sets
        return log
    }

    @Test func nothingLoggedMeansNoLine() {
        #expect(LastTime.line(step(.reps(target: 9), kg: 10), history: []) == nil)
    }

    @Test func usesTheMostRecentLogAndItsBestSet() {
        let old = log(0, [SetLog(exercise: "x", setIndex: 0, reps: 8, kg: 8, asPrescribed: true)])
        let recent = log(7, [SetLog(exercise: "x", setIndex: 0, reps: 8, kg: 10, asPrescribed: true),
                             SetLog(exercise: "x", setIndex: 1, reps: 7, kg: 10, asPrescribed: false)])
        #expect(LastTime.line(step(.reps(target: 9), kg: 10), history: [recent, old])
                == "Last time 8 @ 10 kg → today 9 @ 10 kg")
    }

    @Test func formatsHoldsAndBodyweight() {
        let holds = log(0, [SetLog(exercise: "x", setIndex: 0, seconds: 20, asPrescribed: true)])
        #expect(LastTime.line(step(.hold(seconds: 25), kg: nil), history: [holds]) == "Last time 20 s → today 25 s")
        let sides = log(0, [SetLog(exercise: "x", setIndex: 0, reps: 10, kg: 6, asPrescribed: true)])
        #expect(LastTime.line(step(.perSide(target: 11), kg: 6), history: [sides])
                == "Last time 10 each side @ 6 kg → today 11 each side @ 6 kg")
    }

    /// The UI test's case: Upper A all done in week 1, then week 2's Upper A.
    @Test func secondUpperAShowsLastTimeForEveryLift() throws {
        let programme = try phase1()
        let first = try #require(WorkoutScript.make(sessionID: "upper-a", programme: programme, week: 1))
        var done = SessionLog(programmeID: "phase-1", sessionID: "upper-a", week: 1,
                              startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        done.sets = first.sets.map { $0.prescribedLog() }
        let second = try #require(WorkoutScript.make(sessionID: "upper-a", programme: programme, week: 2, history: [done]))
        let lines = LastTime.lines(for: second, history: [done])
        let doneIDs = Set(done.sets.map(\.exercise))
        for step in second.sets where doneIDs.contains(step.exercise) {
            #expect(lines[step.exercise] != nil, "\(step.exercise)")
        }
        let bench = try #require(lines["dumbbell-bench-press"])
        #expect(bench.hasPrefix("Last time 8 @ 10 kg → today "), "\(bench)")
        #expect(bench != "Last time 8 @ 10 kg → today 8 @ 10 kg", "the bench moved on after an all-done week")
    }
}
