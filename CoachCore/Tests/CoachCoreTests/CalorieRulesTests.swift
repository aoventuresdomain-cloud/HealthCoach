import Foundation
import Testing
@testable import CoachCore

/// Board M4-01: calories adjust from the trend within safe bounds (Advisor, 17 Nov 2026).
@Suite struct CalorieRulesTests {
    let f = CoachFixture()

    private func target(week: Int, _ samples: [WeightSample], blocks: [CoachBlock] = [],
                        phase: Int = 1) -> CalorieTarget {
        CalorieRules.target(on: f.monday(week), start: f.start, phase: phase, samples: samples,
                            blocks: blocks, calendar: f.calendar)
    }

    @Test func startsAt2000WithProtein160() {
        let t = target(week: 1, [])
        #expect(t.kcal == 2_000)
        #expect(t.proteinG == 160)
        #expect(t.reason == .start)
        #expect(t.summary == "2,000 kcal and 160 g protein a day")
    }

    @Test func noChangeInWeeks1And2WhateverTheScaleSays() {
        // Losing 3 kg a week of water: still 2,000 for weeks 1–2.
        let samples = f.losing(3, to: 13)
        #expect(target(week: 2, samples).kcal == 2_000)
        #expect(target(week: 2, samples).lastCheck == nil)
    }

    @Test func onTrackHolds() {
        let samples = f.losing(0.6, to: 60)
        for week in 3...8 {
            let t = target(week: week, samples)
            #expect(t.kcal == 2_000)
            #expect(t.reason == .onTrack)
        }
    }

    @Test func usesTheTwoWeekRateNotOneWeek() throws {
        // Water swings the weekly average ±0.3 kg, but the 2-week rate is 0.5 kg a week.
        let samples = f.weights(to: 40) { day in
            let swing = (day / 7) % 2 == 0 ? 0.3 : -0.3
            return 82 - 0.5 * Double(day) / 7 + swing
        }
        let rate = try #require(CalorieRules.lossRate(samples: samples, endingOn: f.day(20), calendar: f.calendar))
        #expect(abs(rate - 0.5) < 0.01)
        #expect(target(week: 4, samples).kcal == 2_000)
    }

    @Test func slowLossStepsDown100AWeekToTheFloorAndNoFurther() {
        let flat = f.weights(to: 80) { _ in 82 }
        #expect(target(week: 3, flat).kcal == 1_900)
        #expect(target(week: 3, flat).reason == .steppedDown)
        #expect(target(week: 4, flat).kcal == 1_850) // a part step, never under the floor
        #expect(target(week: 5, flat).kcal == 1_850)
        #expect(target(week: 5, flat).reason == .atFloor)
        #expect(target(week: 10, flat).kcal == 1_850)
    }

    @Test func gainingCountsAsSlow() {
        let gaining = f.weights(to: 30) { 82 + 0.3 * Double($0) / 7 }
        #expect(target(week: 3, gaining).kcal == 1_900)
    }

    @Test func fastLossStepsUp100AWeekToTheCeilingAndNoFurther() {
        let fast = f.losing(1.5, to: 60)
        #expect(target(week: 3, fast).kcal == 2_100)
        #expect(target(week: 4, fast).kcal == 2_200)
        #expect(target(week: 5, fast).kcal == 2_200)
        #expect(target(week: 5, fast).reason == .atCeiling)
    }

    @Test func neverMoreThan100BetweenChecksAndAlwaysInsideTheBand() {
        // A wild scale: big drops and gains week to week.
        let wild = f.weights(to: 150) { day in 82 + ((day / 7) % 3 == 0 ? -2.5 : 1.5) }
        var previous = 2_000
        for week in 1...20 where !CalorieRules.isMaintenance(week: week) && !CalorieRules.isMaintenance(week: week - 1) {
            let kcal = target(week: week, wild).kcal
            #expect(abs(kcal - previous) <= 100, "week \(week)")
            #expect(CalorieRules.cutBand.contains(kcal), "week \(week)")
            previous = kcal
        }
    }

    @Test func tooFewWeighInsHolds() {
        // Two weigh-ins a week: never enough for a 7-day average.
        let sparse = f.weights(to: 40) { _ in 82 }.enumerated().filter { $0.offset % 4 == 0 }.map(\.element)
        let t = target(week: 4, sparse)
        #expect(t.kcal == 2_000)
        #expect(t.reason == .notEnoughWeighIns)
    }

    @Test func maintenanceWeeksAreFixedAt2450ThenTheCutResumesAfterSettling() {
        let flat = f.weights(to: 130) { _ in 82 }
        #expect(target(week: 13, flat).kcal == 2_450)
        #expect(target(week: 13, flat).reason == .maintenance)
        #expect(target(week: 14, flat).kcal == 2_450)
        // Back to the cut target (the floor) for weeks 15–16 while water settles, then steps resume.
        #expect(target(week: 15, flat).kcal == 1_850)
        #expect(target(week: 15, flat).reason == .settling)
        #expect(target(week: 16, flat).reason == .settling)
        #expect(target(week: 17, flat).reason == .atFloor)
    }

    @Test func anImportSetsCaloriesAndTheNextCheckLetsItSettle() {
        let flat = f.weights(to: 60) { _ in 82 }
        // Week 3 stepped to 1,900; Claude sets 1,950 on the Tuesday of week 3.
        let blocks = [f.block(on: 15, kcal: 1_950)]
        let midWeek = CalorieRules.target(on: f.day(17), start: f.start, phase: 1, samples: flat,
                                          blocks: blocks, calendar: f.calendar)
        #expect(midWeek.kcal == 1_950)
        #expect(midWeek.reason == .imported)
        #expect(target(week: 4, flat, blocks: blocks).kcal == 1_950) // one check skipped (a 50 kcal change)
        #expect(target(week: 4, flat, blocks: blocks).reason == .settling)
        #expect(target(week: 5, flat, blocks: blocks).kcal == 1_850) // the trend moves it on again
    }

    @Test func aBigImportedChangeSkipsTwoChecks() {
        let flat = f.weights(to: 60) { _ in 82 }
        let blocks = [f.block(on: 15, kcal: 2_200)] // +300 on 1,900
        #expect(target(week: 4, flat, blocks: blocks).reason == .settling)
        #expect(target(week: 5, flat, blocks: blocks).reason == .settling)
        #expect(target(week: 6, flat, blocks: blocks).kcal == 2_100)
    }

    @Test func importedProteinReplacesTheDefault() {
        let t = target(week: 4, [], blocks: [f.block(on: 15, protein: 170)])
        #expect(t.proteinG == 170)
    }

    @Test func dayBandFollowsTheWeeklyTargetAndNeverGoesUnder1700() {
        let at2000 = CalorieTarget(kcal: 2_000, proteinG: 160, reason: .start, lastCheck: nil)
        #expect(at2000.dayBand == 1_850...2_150)
        let atFloor = CalorieTarget(kcal: 1_850, proteinG: 160, reason: .atFloor, lastCheck: nil)
        #expect(atFloor.dayBand == 1_700...2_000)
    }

    @Test func phase3AimsSlower() {
        #expect(CalorieRules.lossRate(phase: 1).target == 0.4...0.8)
        #expect(CalorieRules.lossRate(phase: 2).target == 0.4...0.8)
        #expect(CalorieRules.lossRate(phase: 3).target == 0.3...0.6)
        // 0.25 kg a week is slow in phase 1, but in range for phase 3's slower aim.
        let gentle = f.losing(0.25, to: 30)
        #expect(target(week: 3, gentle, phase: 1).kcal == 1_900)
        #expect(target(week: 3, gentle, phase: 3).kcal == 2_000)
    }
}
