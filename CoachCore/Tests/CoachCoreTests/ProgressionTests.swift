import Foundation
import Testing
@testable import CoachCore

/// Board M1-08: the next session's loads change correctly after logging.
@Suite struct ProgressionTests {
    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    private func item(_ exercise: String, in session: String, _ programme: Programme) throws -> StrengthItem {
        guard case let .strength(s) = try #require(programme.sessions[session]) else {
            throw Problem("\(session) is not a strength session")
        }
        return try #require(s.blocks.flatMap(\.items).first { $0.exercise == exercise })
    }

    struct Problem: Error { let text: String; init(_ text: String) { self.text = text } }

    private let start = Date(timeIntervalSince1970: 1_795_000_000)

    /// One logged session, `n` days after the start, with one set per entry of `reps`.
    private func log(_ n: Int, _ exercise: String, reps: [Int?], kg: Double? = nil, seconds: Bool = false,
                     session: String = "upper-a", slow: Bool = false, recovery: RecoveryCheck? = nil) -> SessionLog {
        let sets = reps.enumerated().map { index, count in
            SetLog(exercise: exercise, setIndex: index,
                   reps: seconds ? nil : count, seconds: seconds ? count : nil,
                   kg: kg, asPrescribed: false, slowTempo: slow)
        }
        let at = start.addingTimeInterval(Double(n) * 86_400)
        return SessionLog(programmeID: "phase-1", sessionID: session, week: n / 7 + 1,
                          startedAt: at, finishedAt: at.addingTimeInterval(2_400), recovery: recovery, sets: sets)
    }

    // MARK: Start and week ramp

    @Test func neverLoggedStartsAtTheProgrammeStart() throws {
        let p = try phase1()
        let bench = try item("dumbbell-bench-press", in: "upper-a", p)
        let rx = try #require(p.prescription(for: bench, week: 1, history: []))
        #expect(rx.step == .start)
        #expect(rx.reps == 8)
        #expect(rx.seconds == nil)
        #expect(rx.kg == 10)
        #expect(rx.sets == 2)
        #expect(rx.repsInReserve == 4)
        #expect(!rx.slowTempo)
        #expect(!rx.atDumbbellLimit)
    }

    @Test func setsComeFromTheWeeklyRamp() throws {
        let p = try phase1()
        let bench = try item("dumbbell-bench-press", in: "upper-a", p)
        #expect(p.prescription(for: bench, week: 2, history: [])?.sets == 3)
        #expect(p.prescription(for: bench, week: 4, history: [])?.repsInReserve == 2)
        #expect(p.prescription(for: bench, week: 7, history: []) == nil)
    }

    // MARK: Reps, then weight (double)

    @Test func everySetOnTargetAddsOneRep() throws {
        let p = try phase1()
        let bench = try item("dumbbell-bench-press", in: "upper-a", p)
        let rx = try #require(p.prescription(for: bench, week: 1, history: [log(0, bench.exercise, reps: [8, 8], kg: 10)]))
        #expect(rx.step == .climb)
        #expect(rx.reps == 9)
        #expect(rx.kg == 10)
    }

    @Test func extraRepsJumpTheTargetForward() throws {
        let p = try phase1()
        let bench = try item("dumbbell-bench-press", in: "upper-a", p)
        let rx = try #require(p.prescription(for: bench, week: 1, history: [log(0, bench.exercise, reps: [11, 10], kg: 10)]))
        #expect(rx.reps == 10)
    }

    @Test func topOfTheRangeAddsOneLoadStepAndRestarts() throws {
        let p = try phase1()
        let bench = try item("dumbbell-bench-press", in: "upper-a", p)
        let rx = try #require(p.prescription(for: bench, week: 2, history: [log(0, bench.exercise, reps: [12, 12], kg: 10)]))
        #expect(rx.step == .addLoad)
        #expect(rx.kg == 12)
        #expect(rx.reps == 8)
    }

    @Test func aLoggedWeightReplacesThePrescribedOne() throws {
        let p = try phase1()
        let bench = try item("dumbbell-bench-press", in: "upper-a", p)
        let rx = try #require(p.prescription(for: bench, week: 1, history: [log(0, bench.exercise, reps: [8, 8], kg: 14)]))
        #expect(rx.kg == 14)
    }

    @Test func historyIsSharedAcrossSessions() throws {
        let p = try phase1()
        let raiseA = try item("dumbbell-lateral-raise", in: "upper-a", p)
        let raiseB = try item("dumbbell-lateral-raise", in: "upper-b", p)
        let history = [log(0, raiseA.exercise, reps: [12, 12], kg: 4, session: "upper-a")]
        #expect(p.prescription(for: raiseB, week: 1, history: history)?.reps == 13)
    }

    // MARK: Held, not failed (design rule 4)

    @Test func oneShortSetIsHeldNotFailed() throws {
        let p = try phase1()
        let bench = try item("dumbbell-bench-press", in: "upper-a", p)
        let history = [
            log(0, bench.exercise, reps: [10, 10], kg: 10),      // → target 10
            log(2, bench.exercise, reps: [10, 7, 10], kg: 10),   // one short set
        ]
        let rx = try #require(p.prescription(for: bench, week: 1, history: history))
        #expect(rx.step == .held)
        #expect(rx.reps == 10)
        #expect(rx.kg == 10)
    }

    @Test func shortSetsThatAreNotConsecutiveAreHeld() throws {
        let p = try phase1()
        let bench = try item("dumbbell-bench-press", in: "upper-a", p)
        let history = [log(0, bench.exercise, reps: [6, 8, 6], kg: 10)]
        #expect(p.prescription(for: bench, week: 2, history: history)?.step == .held)
    }

    @Test func twoShortSetsInARowBackOffToTheBottom() throws {
        let p = try phase1()
        let bench = try item("dumbbell-bench-press", in: "upper-a", p)
        let history = [
            log(0, bench.exercise, reps: [10, 10], kg: 10),     // → 10
            log(2, bench.exercise, reps: [10, 8, 7], kg: 10),   // two short in a row
        ]
        let rx = try #require(p.prescription(for: bench, week: 2, history: history))
        #expect(rx.step == .backOff)
        #expect(rx.reps == 8)
        #expect(rx.kg == 10)
    }

    @Test func twoShortSetsAtTheBottomDropOneLoadStep() throws {
        let p = try phase1()
        let row = try item("dumbbell-one-arm-row", in: "upper-a", p)
        let rx = try #require(p.prescription(for: row, week: 2, history: [log(0, row.exercise, reps: [6, 5, 8], kg: 12)]))
        #expect(rx.step == .backOff)
        #expect(rx.kg == 10)
        #expect(rx.reps == 8)
    }

    @Test func anUnusedCounterNeverHoldsProgressionBack() throws {
        let p = try phase1()
        let bench = try item("dumbbell-bench-press", in: "upper-a", p)
        // Second and third sets: no count (phone down), not tapped "as prescribed".
        let rx = try #require(p.prescription(for: bench, week: 2, history: [log(0, bench.exercise, reps: [8, nil, nil], kg: 10)]))
        #expect(rx.step == .climb)
        #expect(rx.reps == 9)
    }

    @Test func doneAsPrescribedCountsAsOnTarget() throws {
        let p = try phase1()
        let bench = try item("dumbbell-bench-press", in: "upper-a", p)
        let sets = (0..<2).map { SetLog(exercise: bench.exercise, setIndex: $0, kg: 10, asPrescribed: true) }
        let history = [SessionLog(programmeID: "phase-1", sessionID: "upper-a", week: 1, startedAt: start, sets: sets)]
        #expect(p.prescription(for: bench, week: 1, history: history)?.reps == 9)
    }

    // MARK: Reps, then tempo, then weight

    @Test func repsTempoLoadSlowsTheTempoBeforeAddingWeight() throws {
        let p = try phase1()
        let curl = try item("dumbbell-biceps-curl", in: "upper-a", p)
        let top = log(0, curl.exercise, reps: [20, 20], kg: 6)
        let slow = try #require(p.prescription(for: curl, week: 1, history: [top]))
        #expect(slow.step == .slowTempo)
        #expect(slow.slowTempo)
        #expect(slow.reps == 20)
        #expect(slow.kg == 6)

        let slowTop = log(2, curl.exercise, reps: [20, 20], kg: 6, slow: true)
        let heavier = try #require(p.prescription(for: curl, week: 1, history: [top, slowTop]))
        #expect(heavier.step == .addLoad)
        #expect(!heavier.slowTempo)
        #expect(heavier.kg == 8)
        #expect(heavier.reps == 12)
    }

    @Test func bodyweightRepsTempoStopsAtSlowTempo() throws {
        let p = try phase1()
        let bridge = try item("glute-bridge", in: "full-body", p)
        let history = [
            log(0, bridge.exercise, reps: [20, 20], session: "full-body"),
            log(7, bridge.exercise, reps: [20, 20, 20], session: "full-body", slow: true),
        ]
        let rx = try #require(p.prescription(for: bridge, week: 2, history: history))
        #expect(rx.step == .top)
        #expect(rx.slowTempo)
        #expect(rx.kg == nil)
        #expect(!rx.atDumbbellLimit)
    }

    @Test func repsRuleHoldsAtTheTop() throws {
        let p = try phase1()
        let bug = try item("dead-bug", in: "upper-a", p)
        let rx = try #require(p.prescription(for: bug, week: 1, history: [log(0, bug.exercise, reps: [10, 10])]))
        #expect(rx.step == .top)
        #expect(rx.reps == 10)
        #expect(!rx.slowTempo)
    }

    // MARK: Time

    @Test func timeAddsFiveSecondsThenHolds() throws {
        let p = try phase1()
        let plank = try item("plank", in: "upper-a", p)
        let first = try #require(p.prescription(for: plank, week: 1, history: [log(0, plank.exercise, reps: [20, 20], seconds: true)]))
        #expect(first.seconds == 25)
        #expect(first.reps == nil)
        let top = try #require(p.prescription(for: plank, week: 1, history: [log(0, plank.exercise, reps: [45, 45], seconds: true)]))
        #expect(top.step == .top)
        #expect(top.seconds == 45)
    }

    @Test func timeThenLoadAddsWeightAtTheTop() throws {
        let p = try phase1()
        let carry = try item("farmers-carry", in: "full-body", p)
        let rx = try #require(p.prescription(for: carry, week: 1,
            history: [log(0, carry.exercise, reps: [45, 45], kg: 16, seconds: true, session: "full-body")]))
        #expect(rx.step == .addLoad)
        #expect(rx.kg == 18)
        #expect(rx.seconds == 30)
    }

    // MARK: Dumbbell limit (24 kg, decision D3)

    @Test func flagsWhenTheHeaviestDumbbellIsReached() throws {
        let p = try phase1()
        #expect(p.dumbbellLimitKg == 24)
        let carry = try item("farmers-carry", in: "full-body", p)
        let at22 = log(0, carry.exercise, reps: [45, 45], kg: 22, seconds: true, session: "full-body")
        let rx = try #require(p.prescription(for: carry, week: 1, history: [at22]))
        #expect(rx.kg == 24)
        #expect(rx.atDumbbellLimit)
    }

    @Test func neverPrescribesPastTheHeaviestDumbbell() throws {
        let p = try phase1()
        let carry = try item("farmers-carry", in: "full-body", p)
        let at24 = log(0, carry.exercise, reps: [45, 45], kg: 24, seconds: true, session: "full-body")
        let rx = try #require(p.prescription(for: carry, week: 1, history: [at24]))
        #expect(rx.kg == 24)
        #expect(rx.seconds == 45)
        #expect(rx.step == .top)
        #expect(rx.atDumbbellLimit)
    }

    @Test func belowTheLimitIsNotFlagged() throws {
        let p = try phase1()
        let carry = try item("farmers-carry", in: "full-body", p)
        let rx = try #require(p.prescription(for: carry, week: 1,
            history: [log(0, carry.exercise, reps: [30, 30], kg: 20, seconds: true, session: "full-body")]))
        #expect(rx.kg == 20)
        #expect(!rx.atDumbbellLimit)
    }

    // MARK: Graduate and auto-swap

    @Test func negativesGraduateToPullUpsAfterFullSetsAtTheTop() throws {
        let p = try phase1()
        let negatives = try item("negative-pull-up", in: "upper-a", p)
        // Week 1 has 2 sets: the top of the range isn't enough to graduate.
        let twoSets = log(0, negatives.exercise, reps: [5, 5])
        #expect(p.prescription(for: negatives, week: 2, history: [twoSets])?.step == .top)
        #expect(p.prescription(for: negatives, week: 2, history: [twoSets])?.exercise == "negative-pull-up")

        let threeSets = log(7, negatives.exercise, reps: [5, 5, 5])
        let rx = try #require(p.prescription(for: negatives, week: 2, history: [twoSets, threeSets]))
        #expect(rx.step == .graduated)
        #expect(rx.exercise == "pull-up")
        #expect(rx.reps == 1)
        #expect(rx.range == IntRange(min: 1, max: 5))

        let pullUps = log(9, "pull-up", reps: [1, 0, 1])
        let next = try #require(p.prescription(for: negatives, week: 2, history: [twoSets, threeSets, pullUps]))
        #expect(next.exercise == "pull-up")
        #expect(next.step == .held)
        #expect(next.reps == 1)
    }

    @Test func autoSwapHasItsOwnPrescription() throws {
        let p = try phase1()
        let pushUp = try item("push-up", in: "full-body", p)
        let rx = try #require(p.swapPrescription(for: pushUp, week: 1, history: []))
        #expect(rx.exercise == "dumbbell-bench-press")
        #expect(rx.kg == 10)
        #expect(rx.reps == 8)
        let plank = try item("plank", in: "upper-a", p)
        #expect(p.swapPrescription(for: plank, week: 1, history: []) == nil)
    }

    // MARK: Drop to 2 strength sessions (decision R2)

    @Test func twoSoreChecksDropTheFullBodySession() throws {
        let p = try phase1()
        let history = [
            log(0, "plank", reps: [20], session: "upper-a", recovery: .sore),
            log(2, "plank", reps: [20], session: "upper-b", recovery: .sore),
        ]
        #expect(p.reducedWeekApplies(history: history))
        #expect(p.droppedSessions(history: history) == ["full-body"])
    }

    @Test func oneSoreCheckOrAnIgnoredRowKeepsTheFullWeek() throws {
        let p = try phase1()
        #expect(!p.reducedWeekApplies(history: []))
        #expect(!p.reducedWeekApplies(history: [log(0, "plank", reps: [20], recovery: .sore)]))
        let ignoredLast = [
            log(0, "plank", reps: [20], session: "upper-a", recovery: .sore),
            log(2, "plank", reps: [20], session: "upper-b", recovery: nil),
        ]
        #expect(!p.reducedWeekApplies(history: ignoredLast))
        #expect(p.droppedSessions(history: ignoredLast).isEmpty)
    }

    @Test func aFineCheckEndsTheReducedWeek() throws {
        let p = try phase1()
        let history = [
            log(0, "plank", reps: [20], session: "upper-a", recovery: .sore),
            log(2, "plank", reps: [20], session: "upper-b", recovery: .sore),
            log(7, "plank", reps: [20], session: "upper-a", recovery: .fine),
        ]
        #expect(!p.reducedWeekApplies(history: history))
    }

    @Test func runsDoNotCountAsRecoveryChecks() throws {
        let p = try phase1()
        let history = [
            log(0, "plank", reps: [20], session: "upper-a", recovery: .sore),
            log(1, "plank", reps: [], session: "run-1", recovery: .fine),
            log(2, "plank", reps: [20], session: "upper-b", recovery: .sore),
        ]
        #expect(p.reducedWeekApplies(history: history))
    }
}
