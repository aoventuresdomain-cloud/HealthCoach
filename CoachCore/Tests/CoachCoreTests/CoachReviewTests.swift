import Foundation
import Testing
@testable import CoachCore

/// Board M4-01: a simulated 2-week stall raises a flag; load from the logs,
/// volume from recovery. A flag never changes the plan.
@Suite struct CoachReviewTests {
    let f = CoachFixture()

    private func review(at date: Date, weights: [WeightSample] = [], history: [SessionLog] = [],
                        blocks: [CoachBlock] = []) throws -> CoachReview {
        try #require(CoachReview.make(programme: try f.phase1(), profile: f.profile(), history: history,
                                      weights: weights, blocks: blocks, now: date, calendar: f.calendar))
    }

    @Test func twoWeekStallRaisesAFlag() throws {
        let flat = f.weights(to: 40) { _ in 82 }
        // Week 3's check alone isn't two weeks running.
        #expect(try review(at: f.monday(3), weights: flat).flags.isEmpty)
        // Weeks 3 and 4 both flat: flagged.
        let week4 = try review(at: f.monday(4), weights: flat)
        #expect(week4.flags == [.stall(.weightFlat)])
        #expect(week4.flags.first?.line == "Your weight has been flat for 2 weeks. Ask the coach.")
    }

    @Test func steadyLossRaisesNoFlag() throws {
        let losing = f.losing(0.6, to: 40)
        for week in 3...6 {
            #expect(try review(at: f.monday(week), weights: losing).flags.isEmpty)
        }
    }

    @Test func atTheFloorAndStillFlatFlagsTheFloor() throws {
        let flat = f.weights(to: 40) { _ in 82 }
        let week5 = try review(at: f.monday(5), weights: flat)
        #expect(week5.calories.kcal == 1_850)
        #expect(week5.flags == [.stall(.calorieFloor)])
    }

    @Test func losingTooFastAtTheCeilingFlags() throws {
        let fast = f.losing(1.5, to: 40)
        #expect(try review(at: f.monday(4), weights: fast).flags.isEmpty) // reached 2,200 this check
        #expect(try review(at: f.monday(5), weights: fast).flags == [.stall(.losingTooFast)])
    }

    @Test func phase3FlagsLosingTooFastFromOneKiloAWeek() {
        // 1.1 kg a week at the ceiling, two checks running: fine in phases 1–2, flagged in phase 3.
        let checks = [16, 17].map { week in
            CalorieCheck(date: f.monday(week), week: week, lossRateKg: 1.1,
                         kcalBefore: 2_200, kcalAfter: 2_200, outcome: .atCeiling)
        }
        func reason(_ phase: Int) -> CoachFlag.StallReason? {
            CoachReview.stallReason(checks: checks, blocks: [], now: f.monday(17), week: 17, phase: phase)
        }
        #expect(reason(2) == nil)
        #expect(reason(3) == .losingTooFast)
        // Only one check over the line is not enough.
        var single = checks
        single[0] = CalorieCheck(date: f.monday(16), week: 16, lossRateKg: 0.9,
                                 kcalBefore: 2_200, kcalAfter: 2_200, outcome: .atCeiling)
        #expect(CoachReview.stallReason(checks: single, blocks: [], now: f.monday(17), week: 17, phase: 3) == nil)
    }

    @Test func importingAfterAFlagClearsIt() throws {
        let flat = f.weights(to: 40) { _ in 82 }
        let blocks = [f.block(on: 22, kcal: 1_950)] // Tuesday of week 4
        #expect(try review(at: f.day(23, hour: 9), weights: flat, blocks: blocks).flags.isEmpty)
    }

    @Test func noFlagsInMaintenanceWeeks() throws {
        let flat = f.weights(to: 100) { _ in 82 }
        #expect(try review(at: f.monday(13), weights: flat).flags.isEmpty)
        #expect(try review(at: f.monday(14), weights: flat).flags.isEmpty)
    }

    @Test func aFlagDoesNotChangeThePlan() throws {
        let flat = f.weights(to: 40) { _ in 82 }
        let flagged = try review(at: f.monday(4), weights: flat)
        let expected = CalorieRules.target(on: f.monday(4), start: f.start, phase: 1, samples: flat,
                                           blocks: [], calendar: f.calendar)
        #expect(flagged.calories == expected)
        #expect(flagged.droppedSessions.isEmpty)
    }

    @Test func checkpointOneOpensOnSaturdayOfWeek6() throws {
        #expect(try review(at: f.day(39, hour: 9)).flags.isEmpty)            // Friday, week 6
        #expect(try review(at: f.day(40, hour: 9)).flags == [.checkpoint(1)]) // Saturday
        #expect(try review(at: f.day(43, hour: 9)).flags == [.checkpoint(1)]) // Tuesday, week 7
        // Answered: an import after it opened closes it.
        let blocks = [f.block(on: 41, kcal: 1_950)]
        #expect(try review(at: f.day(42, hour: 9), blocks: blocks).flags.isEmpty)
        // Closed after the week that follows it.
        #expect(try review(at: f.day(49, hour: 9)).flags.isEmpty)
    }

    @Test func volumeFromRecoveryAndFromAnImport() throws {
        let sore = (0..<2).map { n in
            SessionLog(programmeID: "phase-1", sessionID: "upper-a", week: 1,
                       startedAt: f.day(n * 2, hour: 7), finishedAt: f.day(n * 2, hour: 8), recovery: .sore)
        }
        #expect(try review(at: f.day(5), history: sore).droppedSessions == ["full-body"])
        let blocks = [f.block(on: 5, drop: ["run-1"])]
        #expect(try review(at: f.day(7), blocks: blocks).droppedSessions == ["run-1"])
        #expect(try review(at: f.day(14), blocks: blocks).droppedSessions.isEmpty) // one week only
    }

    @Test func dumbbellLimitListsExercisesAtTheTop() throws {
        // Farmer's carry: imported at 24 kg, the heaviest dumbbell.
        let blocks = [f.block(on: 1, loads: [.init(exercise: "farmers-carry", kg: 24)])]
        let r = try review(at: f.day(3), blocks: blocks)
        #expect(r.dumbbellLimit == ["farmers-carry"])
    }

    /// C2: one line on Today, flags first, then the dumbbell limit; none on a normal week.
    @Test func todayLineShowsOneReasonOrNothing() throws {
        let names = { (id: String) in id == "farmers-carry" ? "Farmer's carry" : id }
        #expect(try review(at: f.day(3)).todayLine(name: names) == nil)
        let flat = f.weights(to: 40) { _ in 82 }
        #expect(try review(at: f.monday(4), weights: flat).todayLine(name: names)
                == "Your weight has been flat for 2 weeks. Ask the coach.")
        #expect(try review(at: f.day(40, hour: 9)).todayLine(name: names) == "Checkpoint 1: time for your coach review.")
        let blocks = [f.block(on: 1, loads: [.init(exercise: "farmers-carry", kg: 24)])]
        #expect(try review(at: f.day(3), blocks: blocks).todayLine(name: names)
                == "Farmer's carry is at your heaviest dumbbell. Ask the coach.")
    }

    @Test func nilBeforeOnboarding() throws {
        var profile = f.profile()
        profile.programme.startDate = nil
        #expect(CoachReview.make(programme: try f.phase1(), profile: profile, history: [], weights: [],
                                 blocks: [], now: f.day(3), calendar: f.calendar) == nil)
    }
}
