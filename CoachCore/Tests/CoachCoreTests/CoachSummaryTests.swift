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
}
