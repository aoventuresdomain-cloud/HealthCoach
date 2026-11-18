import Foundation
import Testing
@testable import CoachCore

/// Board M4-02 (and M4-03's "Ask the coach now"): the summary to share with
/// Claude, ending in the reply format the importer reads.
@Suite struct CoachSummaryTests {
    let f = CoachFixture()

    private func summary(reason: CoachSummary.Reason? = nil, profile: Profile? = nil,
                         weights: [WeightSample]? = nil, at date: Date? = nil) throws -> String {
        let now = date ?? f.monday(4)
        let steps = (1...7).map { StepCount(day: f.day(21 - $0), steps: 9_000) }
        return try #require(CoachSummary.text(
            reason: reason, programme: try f.phase1(), profile: profile ?? f.profile(), history: [],
            weights: weights ?? f.weights(to: 21) { _ in 82 }, steps: steps, blocks: [],
            now: now, calendar: f.calendar))
    }

    @Test func leadsWithTheStallAndCarriesTheNumbers() throws {
        let text = try summary()
        #expect(text.hasPrefix("HealthCoach · Stall flag: Your weight has been flat for 2 weeks. Ask the coach.\nMon 7 Dec 2026"))
        #expect(text.contains("- Weight: 82.0 kg (7-day average), level with last week (7 of 7 days weighed)"))
        #expect(text.contains("- 2-week rate: losing 0 kg a week (aim 0.4–0.8 kg)"))
        #expect(text.contains("- Steps: 9,000 a day (7-day average)"))
        #expect(text.contains("- Target: 1,850 kcal and 160 g protein a day"))
        #expect(text.contains("  - dumbbell-bench-press: 10 kg × 8 reps"))
        #expect(text.contains("Flags\n- Your weight has been flat for 2 weeks. Ask the coach."))
    }

    @Test func askNowIsACheckIn() throws {
        let text = try summary(reason: .askNow, weights: f.losing(0.6, to: 21))
        #expect(text.hasPrefix("HealthCoach · Check-in\n"))
        #expect(!text.contains("Flags\n"))
    }

    @Test func theExampleReplyImports() throws {
        // What Claude copies back must pass the importer: the template is the contract.
        let text = try summary()
        let begin = try #require(text.range(of: CoachImport.beginMarker))
        let end = try #require(text.range(of: CoachImport.endMarker))
        let example = String(text[begin.lowerBound..<end.upperBound])
        let result = CoachImport.importing(example, into: [], programme: try f.phase1(), profile: f.profile(),
                                           now: f.monday(4), calendar: f.calendar)
        #expect(result.error == nil)
        #expect(result.accepted?.dailyKcal == 1_850)
        // Today's numbers, so copying the example unedited moves nothing.
        #expect(result.accepted?.loads == [.init(exercise: "dumbbell-goblet-squat", kg: 12)])
    }

    @Test func listsTheBoundsTheImporterChecks() throws {
        let text = try summary()
        #expect(text.contains("dailyKcal: 1,850–2,200. proteinG: 140–180."))
        #expect(text.contains("dropSessions: any of full-body, run-1, run-2, upper-a, upper-b"))
        #expect(text.contains("up to 24 kg"))
    }

    @Test func carriesNoNameAndNoRawSamples() throws {
        var profile = f.profile()
        profile.about.name = "Sam Example"
        let text = try summary(profile: profile)
        #expect(!text.contains("Sam"))
        // Averages only: no per-day weigh-in lines.
        #expect(!text.contains("07:00"))
    }

    @Test func nilBeforeOnboarding() throws {
        var profile = f.profile()
        profile.programme.startDate = nil
        #expect(CoachSummary.text(programme: try f.phase1(), profile: profile, history: [], weights: [],
                                  blocks: [], now: f.monday(4), calendar: f.calendar) == nil)
    }

    // MARK: QA-R4 J3.7

    /// J3.7: with a full week of check-in answers, the summary carries them
    /// as words and counts only, and no photo, name, raw sample or timestamp.
    /// Its example block still imports and moves nothing.
    @Test func theCheckInGoesAsCountsAndTheExampleStillMovesNothing() throws {
        let now = f.monday(4)               // Mon 7 Dec, day 21
        var profile = f.profile()
        profile.about.name = "Sam Example"
        let p = try f.phase1()
        // Per-day values that can't appear by chance in an average.
        let weights = f.weights(to: 21) { 82 + Double($0 % 3) * 0.13 }
        let steps = (1...7).map { StepCount(day: f.day(21 - $0), steps: $0.isMultiple(of: 2) ? 9_137 : 8_863) }
        let checkIns = [CheckIn(date: f.day(13, hour: 18), pain: [.knee]),
                        CheckIn(date: f.day(20, hour: 18), energy: .low, sleep: .poor, pain: [.knee, .other])]
        let text = try #require(CoachSummary.text(
            reason: .askNow, programme: p, profile: profile, history: [], weights: weights, steps: steps,
            blocks: [], socialMeals: [f.day(18)], checkIns: checkIns, now: now, calendar: f.calendar))

        // The answers, as words and counts.
        #expect(text.contains("- Check-in: energy low, sleep poor, pain knee, other"))
        #expect(text.contains("- Low energy and poor sleep together: counted as one low-recovery signal"))
        #expect(text.contains("- Exercises loading the knee swapped for 7 days"))
        #expect(text.contains("- " + CheckIn.stillSoreLine))
        #expect(text.contains("a day (7-day average)"))

        // Nothing personal or raw.
        for banned in ["Sam", "Example", "photo", "Photo", ".jpg", ".heic", ".png", "file:", "waist",
                       "9,137", "8,863", "82.13", "82.26", "2026-", "T18:", ":00:00"] {
            #expect(!text.contains(banned), "summary contains \(banned)")
        }

        // The example block imports and changes nothing: same target, same loads.
        let begin = try #require(text.range(of: CoachImport.beginMarker))
        let end = try #require(text.range(of: CoachImport.endMarker))
        let outcome = CoachImport.importing(String(text[begin.lowerBound..<end.upperBound]), into: [], programme: p,
                                            profile: profile, now: now, calendar: f.calendar)
        #expect(outcome.error == nil, "\(outcome.message)")
        let review = { (blocks: [CoachBlock]) in
            CoachReview.make(programme: p, profile: profile, history: [], weights: weights, blocks: blocks,
                             checkIns: checkIns, now: f.monday(5), calendar: f.calendar)
        }
        let without = try #require(review([])), with = try #require(review(outcome.blocks))
        // The amounts, not the wording: the import's own check-in may change the reason line.
        #expect(with.calories.kcal == without.calories.kcal)
        #expect(with.calories.proteinG == without.calories.proteinG)
        #expect(with.droppedSessions == without.droppedSessions)
        let loads = { (blocks: [CoachBlock]) in
            p.strengthItems.compactMap {
                p.prescription(for: $0, week: 5, history: [], blocks: blocks, checkIns: checkIns,
                               on: f.monday(5), calendar: f.calendar)?.kg
            }
        }
        #expect(loads(outcome.blocks) == loads([]))
    }
}
