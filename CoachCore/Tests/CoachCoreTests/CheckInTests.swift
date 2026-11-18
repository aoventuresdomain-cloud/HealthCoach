import Foundation
import Testing
@testable import CoachCore

/// Board N1: the Sunday check-in (Advisor A1). Week 2 of the Gate 1 plan:
/// start Mon 16 Nov 2026, check-in Sunday 29 Nov at 18:00.
@Suite struct CheckInTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func at(_ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: h, minute: min))!
    }

    private func library() throws -> ContentLibrary { try ContentLibrary.load(from: contentRoot) }
    private func phase1() throws -> Programme { try #require(library().programmes["phase-1"]) }

    private func profile() -> Profile {
        var p = Profile()
        p.confirmed = true
        p.programme.startDate = at(11, 16)
        p.programme.confirmedOn = at(11, 15, 18)
        return p
    }

    private func log(_ id: String, _ m: Int, _ d: Int, recovery: RecoveryCheck? = nil) -> SessionLog {
        var log = SessionLog(programmeID: "phase-1", sessionID: id, week: 2, startedAt: at(m, d, 7),
                             finishedAt: at(m, d, 7, 45))
        log.recovery = recovery
        return log
    }

    // MARK: Answers

    @Test func defaultsAreGoodFineNone() {
        let checkIn = CheckIn(date: at(11, 29, 18))
        #expect(checkIn.energy == .good && checkIn.sleep == .fine && checkIn.pain.isEmpty)
        #expect(!checkIn.isLowRecovery)
    }

    @Test func onlyLowEnergyWithPoorSleepIsALowRecoverySignal() {
        #expect(CheckIn(date: at(11, 29), energy: .low, sleep: .poor).isLowRecovery)
        #expect(!CheckIn(date: at(11, 29), energy: .low, sleep: .fine).isLowRecovery)
        #expect(!CheckIn(date: at(11, 29), energy: .ok, sleep: .poor).isLowRecovery)
    }

    @Test func dueOnTheCheckInDayFromItsTimeOnce() {
        let p = profile() // Sunday 18:00 by default
        #expect(!CheckIn.isDue(on: at(11, 29, 17, 59), profile: p, last: nil, calendar: calendar))
        #expect(CheckIn.isDue(on: at(11, 29, 18), profile: p, last: nil, calendar: calendar))
        #expect(!CheckIn.isDue(on: at(11, 28, 19), profile: p, last: nil, calendar: calendar))
        let done = CheckIn(date: at(11, 29, 18, 5))
        #expect(!CheckIn.isDue(on: at(11, 29, 20), profile: p, last: done, calendar: calendar))
        var moved = p
        moved.coach.checkInDay = .saturday
        #expect(CheckIn.isDue(on: at(11, 28, 19), profile: moved, last: done, calendar: calendar))
    }

    // MARK: The drop-to-2 rule (R2)

    @Test func aLowCheckInCountsWithOneSoreAnswer() throws {
        let p1 = try phase1()
        let sore = [log("upper-a", 11, 23, recovery: .sore)]
        let low = CheckIn(date: at(11, 29, 18), energy: .low, sleep: .poor)
        #expect(!p1.reducedWeekApplies(history: sore))
        #expect(p1.reducedWeekApplies(history: sore, checkIns: [low]))
        #expect(p1.droppedSessions(history: sore, checkIns: [low]) == p1.reducedWeek.drop)
        // Either alone: Claude only, no drop.
        let tired = CheckIn(date: at(11, 29, 18), energy: .low, sleep: .fine)
        #expect(!p1.reducedWeekApplies(history: sore, checkIns: [tired]))
        // A Fine session after the low check-in lifts it, as before.
        let fine = sore + [log("upper-a", 11, 30, recovery: .fine)]
        #expect(!p1.reducedWeekApplies(history: fine, checkIns: [low]))
    }

    @Test func noAnswerEverChangesCaloriesAndSkippingChangesNothing() throws {
        let p1 = try phase1()
        let weights = (0..<28).map { WeightSample(date: at(11, 2 + $0, 7), kg: 84 - Double($0) * 0.05) }
        let history = [log("upper-a", 11, 23), log("run-1", 11, 24), log("full-body", 11, 26)]
        func review(_ checkIns: [CheckIn]) throws -> CoachReview {
            try #require(CoachReview.make(programme: p1, profile: profile(), history: history, weights: weights,
                                          blocks: [], checkIns: checkIns, now: at(11, 29, 18, 30), calendar: calendar))
        }
        let skipped = try review([])
        let worst = try review([CheckIn(date: at(11, 29, 18), energy: .low, sleep: .poor, pain: [.knee, .back])])
        #expect(worst.calories == skipped.calories)
        // A plain check-in changes nothing at all.
        #expect(try review([CheckIn(date: at(11, 29, 18))]) == skipped)
    }

    // MARK: Pain

    @Test func painSwapsLastSevenDays() {
        let knee = CheckIn(date: at(11, 29, 18), pain: [.knee])
        #expect(CheckIn.painAreas([knee], on: at(11, 29, 19), calendar: calendar) == [.knee])
        #expect(CheckIn.painAreas([knee], on: at(12, 5, 23), calendar: calendar) == [.knee])
        #expect(CheckIn.painAreas([knee], on: at(12, 6, 7), calendar: calendar).isEmpty)
        #expect(CheckIn.painAreas([knee], on: at(11, 28, 7), calendar: calendar).isEmpty)
    }

    @Test func kneePainTakesEveryKneeLoadingLiftOutOfFullBody() throws {
        let lib = try library(), p1 = try phase1()
        let swaps = PainSwaps.make(areas: [.knee], exercises: PainSwaps.exercises(in: p1), catalogue: lib.exercises)
        #expect(swaps["dumbbell-goblet-squat"]?.to == "glute-bridge")
        #expect(swaps["split-squat"] != nil)
        let script = try #require(WorkoutScript.make(sessionID: "full-body", programme: p1, week: 2,
                                                     painSwaps: swaps, calendar: calendar))
        let plain = try #require(WorkoutScript.make(sessionID: "full-body", programme: p1, week: 2, calendar: calendar))
        let used = Set(script.sets.map(\.exercise))
        for id in used {
            let loads = lib.exercises.exercise(id)?.loads ?? []
            let safe = !loads.contains(.knee)
            #expect(safe, "\(id) loads the knee")
        }
        #expect(used.contains("dumbbell-romanian-deadlift"), "the rest of the session stays")
        #expect(script.sets.count < plain.sets.count)
        // "Other" never swaps anything.
        #expect(PainSwaps.make(areas: [.other], exercises: PainSwaps.exercises(in: p1), catalogue: lib.exercises).isEmpty)
    }

    @Test func everyAreaLeavesNoLoadingExerciseInAnySession() throws {
        let lib = try library()
        for programme in lib.phases {
            for area in PainArea.allCases where area != .other {
                let swaps = PainSwaps.make(areas: [area], exercises: PainSwaps.exercises(in: programme),
                                           catalogue: lib.exercises)
                for (id, session) in programme.sessions {
                    guard case .strength = session,
                          let script = WorkoutScript.make(sessionID: id, programme: programme, week: 1,
                                                          painSwaps: swaps, calendar: calendar) else { continue }
                    for step in script.sets {
                        let loads = lib.exercises.exercise(step.exercise)?.loads ?? []
                        let safe = !loads.contains(area)
                        #expect(safe, "\(programme.id) \(id): \(step.exercise) loads the \(area)")
                    }
                }
            }
        }
    }

    // MARK: Advisor conditions

    /// A catalogue whose `chain-1` swaps along chain-2 ... chain-8; chain-N
    /// loads the knee for every N below `firstSafe`.
    private func chainCatalogue(firstSafe: Int) throws -> ExerciseCatalogue {
        let real = try library().exercises
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(real)) as? [String: Any])
        var exercises = try #require(json["exercises"] as? [[String: Any]])
        let template = try #require(exercises.first)
        for n in 1...8 {
            var e = template
            e["id"] = "chain-\(n)"
            e["swap"] = n < 8 ? "chain-\(n + 1)" : nil
            e["loads"] = n < firstSafe ? ["knee"] : []
            exercises.append(e)
        }
        json["exercises"] = exercises
        return try ExerciseCatalogue.decode(JSONSerialization.data(withJSONObject: json), file: "chain.json")
    }

    @Test func conditionA_theChainStopsAfterFiveSteps() throws {
        let fifth = try PainSwaps.make(areas: [.knee], exercises: ["chain-1"], catalogue: chainCatalogue(firstSafe: 6))
        #expect(fifth["chain-1"]?.to == "chain-6", "five steps along is still found")
        let sixth = try PainSwaps.make(areas: [.knee], exercises: ["chain-1"], catalogue: chainCatalogue(firstSafe: 7))
        #expect(sixth["chain-1"] != nil)
        #expect(sixth["chain-1"]?.to == nil, "six steps along is too far: dropped")
        #expect(PainSwaps.maxChainSteps == 5)
    }

    @Test func conditionA_theChainStopsAtTheFirstRepeat() throws {
        let lib = try library()
        // The real catalogue has loops (squat to split squat and back); every
        // loading exercise ends with an answer rather than hanging.
        let all = lib.exercises.exercises.map(\.id)
        for area in PainArea.allCases where area != .other {
            let swaps = PainSwaps.make(areas: [area], exercises: all, catalogue: lib.exercises)
            for (id, swap) in swaps {
                if let to = swap.to {
                    let loads = lib.exercises.exercise(to)?.loads ?? []
                    let safe = !loads.contains(area) && to != id
                    #expect(safe, "\(id) to \(to) for \(area)")
                }
            }
        }
    }

    /// Advisor review of #103: shoulder chains used to end on scapular push-up.
    @Test func shoulderPainNeverLeavesScapularPushUpInASession() throws {
        let lib = try library()
        let swaps = PainSwaps.make(areas: [.shoulder], exercises: lib.exercises.exercises.map(\.id),
                                   catalogue: lib.exercises)
        let safe = !swaps.values.contains { $0.to == "scapular-push-up" }
        #expect(safe)
        for programme in lib.phases {
            let swaps = PainSwaps.make(areas: [.shoulder], exercises: PainSwaps.exercises(in: programme),
                                       catalogue: lib.exercises)
            for week in programme.effort.map(\.week) {
                for (id, session) in programme.sessions {
                    guard case .strength = session,
                          let script = WorkoutScript.make(sessionID: id, programme: programme, week: week,
                                                          painSwaps: swaps, calendar: calendar) else { continue }
                    let clear = !script.sets.contains { $0.exercise == "scapular-push-up" }
                    #expect(clear, "\(programme.id) \(id) week \(week)")
                }
            }
        }
    }

    /// Advisor review of #103: the chest-supported row is the back-pain swap for the one-arm row.
    @Test func backPainSwapsTheOneArmRowForTheInclineRow() throws {
        let lib = try library()
        let swaps = PainSwaps.make(areas: [.back], exercises: ["dumbbell-one-arm-row"], catalogue: lib.exercises)
        #expect(swaps["dumbbell-one-arm-row"]?.to == "dumbbell-incline-row")
        let elbow = PainSwaps.make(areas: [.elbow], exercises: ["farmers-carry", "hanging-knee-raise"],
                                   catalogue: lib.exercises)
        #expect(elbow.keys.sorted() == ["farmers-carry", "hanging-knee-raise"])
    }

    @Test func conditionB_aDroppedExerciseIsNeverReplaced() throws {
        let lib = try library(), p1 = try phase1()
        var swaps = PainSwaps.make(areas: [.shoulder], exercises: PainSwaps.exercises(in: p1), catalogue: lib.exercises)
        let plain = try #require(WorkoutScript.make(sessionID: "upper-a", programme: p1, week: 2, calendar: calendar))
        // Force a drop: the first exercise has no safe swap.
        let dropped = try #require(plain.sets.first?.exercise)
        swaps[dropped] = PainSwaps.Swap(to: nil, loaded: false)
        let script = try #require(WorkoutScript.make(sessionID: "upper-a", programme: p1, week: 2,
                                                     painSwaps: swaps, calendar: calendar))
        #expect(!script.sets.contains { $0.exercise == dropped })
        // Every exercise left is an original or one original's swap, with that
        // one original's set count: nothing added anywhere, and two
        // exercises swapping to the same one don't double it up.
        let originals = Dictionary(grouping: plain.sets, by: \.exercise).mapValues(\.count)
        let actual = Dictionary(grouping: script.sets, by: \.exercise).mapValues(\.count)
        for (id, count) in actual {
            let sources = originals.filter { original, _ in
                original != dropped && (swaps[original].map { $0.to == id } ?? (original == id))
            }
            let fromOne = sources.values.contains(count)
            #expect(fromOne, "\(id): \(count) sets from \(sources)")
        }
        #expect(script.sets.count < plain.sets.count, "just shorter")
    }

    @Test func conditionC_kneeOrBackPainMakesTheRunWalkABriskWalk() throws {
        let p1 = try phase1()
        guard case let .runWalk(run)? = p1.sessions["run-1"] else { Issue.record("no run-1"); return }
        for areas: Set<PainArea> in [[.knee], [.back], [.knee, .shoulder]] {
            let plan = try #require(RunWalkPlan.make(sessionID: "run-1", session: run, week: 2, painAreas: areas))
            #expect(plan.repeats == 0 && plan.jogSeconds == 0)
            #expect(plan.segments.map(\.kind) == [.briskWalk])
            #expect(RunWalkPlan.briskWalkMinutes.contains(plan.totalSeconds / 60))
        }
        for areas: Set<PainArea> in [[], [.shoulder], [.other]] {
            let plan = try #require(RunWalkPlan.make(sessionID: "run-1", session: run, week: 2, painAreas: areas))
            #expect(plan == RunWalkPlan.make(sessionID: "run-1", session: run, week: 2))
        }
        // Held to 20-30 minutes whatever the week's length.
        for week in run.weeks.map(\.week) {
            let plan = try #require(RunWalkPlan.briskWalk(sessionID: "run-1", session: run, week: week))
            #expect((20...30).contains(plan.totalSeconds / 60))
        }
        // One What-changed line, and only for knee or back.
        #expect(PainSwaps.runWalkLine(areas: [.knee], minutes: 25) == "Run-walk is a brisk 25-minute walk this week: easier on the knee.")
        #expect(PainSwaps.runWalkLine(areas: [.knee, .back], minutes: 20) == "Run-walk is a brisk 20-minute walk this week: easier on the knee and back.")
        #expect(PainSwaps.runWalkLine(areas: [.shoulder, .other], minutes: 25) == nil)
        // Seven days, as the swaps.
        let knee = CheckIn(date: at(11, 29, 18), pain: [.knee])
        #expect(PainSwaps.walksInsteadOfRunning(CheckIn.painAreas([knee], on: at(12, 5, 7), calendar: calendar)))
        #expect(!PainSwaps.walksInsteadOfRunning(CheckIn.painAreas([knee], on: at(12, 6, 7), calendar: calendar)))
    }

    @Test func conditionD_otherOnlyGoesToTheSummary() throws {
        let lib = try library(), p1 = try phase1()
        #expect(PainSwaps.make(areas: [.other], exercises: PainSwaps.exercises(in: p1), catalogue: lib.exercises).isEmpty)
        #expect(!PainSwaps.walksInsteadOfRunning([.other]))
        let text = try #require(CoachSummary.text(programme: p1, profile: profile(), history: [], weights: [],
                                                  blocks: [], checkIns: [CheckIn(date: at(11, 29, 18), pain: [.other])],
                                                  now: at(11, 29, 18, 30), calendar: calendar))
        #expect(text.contains("- Check-in: energy good, sleep fine, pain other"))
        #expect(!text.contains("swapped for"))
    }

    @Test func conditionD_sameAreaTwiceRunningAddsTheGPLine() throws {
        let p1 = try phase1()
        let first = CheckIn(date: at(11, 22, 18), pain: [.shoulder, .other])
        #expect(CheckIn.stillSore([first], asOf: at(11, 29, 19)).isEmpty)
        #expect(CheckIn.stillSore([first, CheckIn(date: at(11, 29, 18), pain: [.shoulder])], asOf: at(11, 29, 19)) == [.shoulder])
        #expect(CheckIn.stillSore([first, CheckIn(date: at(11, 29, 18), pain: [.other])], asOf: at(11, 29, 19)) == [.other])
        // A different area, or a clear week, isn't "still sore".
        #expect(CheckIn.stillSore([first, CheckIn(date: at(11, 29, 18), pain: [.elbow])], asOf: at(11, 29, 19)).isEmpty)
        #expect(CheckIn.stillSore([first, CheckIn(date: at(11, 29, 18))], asOf: at(11, 29, 19)).isEmpty)

        func summary(_ second: [PainArea]) throws -> String {
            try #require(CoachSummary.text(programme: p1, profile: profile(), history: [], weights: [], blocks: [],
                                           checkIns: [first, CheckIn(date: at(11, 29, 18), pain: second)],
                                           now: at(11, 29, 18, 30), calendar: calendar))
        }
        #expect(try summary([.shoulder]).contains("- Still sore after 2 weeks: worth seeing a GP or physio."))
        #expect(try !summary([.elbow]).contains("Still sore"))
    }

    // MARK: Pre-fill and summary

    @Test func theScreenOpensFilledIn() throws {
        let p1 = try phase1()
        let weights = (0..<14).map { WeightSample(date: at(11, 16 + $0, 7), kg: $0 < 7 ? 84 : 83.5) }
        let steps = (0..<7).map { StepCount(day: at(11, 22 + $0), steps: 8_000) }
        let history = [log("upper-a", 11, 23), log("run-1", 11, 24), log("full-body", 11, 26)]
        let prefill = CheckInPrefill.make(now: at(11, 29, 18), programme: p1, profile: profile(), history: history,
                                          weights: weights, steps: steps, calendar: calendar)
        #expect(prefill.weightAverageKg == 83.5)
        #expect(prefill.weightChangeKg.map { abs($0 + 0.5) < 0.001 } == true)
        #expect(prefill.sessionsDone == 3)
        #expect(prefill.sessionsPlanned >= 4, "\(prefill.sessionsPlanned)")
        #expect(prefill.averageSteps == 8_000)
    }

    @Test func theSummarySaysWhatTheCheckInDid() throws {
        let p1 = try phase1()
        let checkIns = [CheckIn(date: at(11, 22, 18), pain: [.knee]),
                        CheckIn(date: at(11, 29, 18), energy: .low, sleep: .poor, pain: [.knee])]
        let text = try #require(CoachSummary.text(programme: p1, profile: profile(), history: [], weights: [],
                                                  blocks: [], checkIns: checkIns, now: at(11, 29, 18, 30),
                                                  calendar: calendar))
        #expect(text.contains("- Check-in: energy low, sleep poor, pain knee"))
        #expect(text.contains("- Low energy and poor sleep together: counted as one low-recovery signal"))
        #expect(text.contains("- Exercises loading the knee swapped for 7 days"))
        #expect(text.contains("- Still sore after 2 weeks: worth seeing a GP or physio."))
        let none = try #require(CoachSummary.text(programme: p1, profile: profile(), history: [], weights: [],
                                                  blocks: [], now: at(11, 29, 18, 30), calendar: calendar))
        #expect(!none.contains("Check-in:"))
    }
}
