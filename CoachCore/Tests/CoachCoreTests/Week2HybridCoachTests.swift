import Foundation
import Testing
@testable import CoachCore

/// Gate 1–2 checklist §A, the CoachCore twin for the coach steps (A5, A12,
/// A13, A16, A17). It runs the scripted hybrid week 2 (Mon 23 – Sun 29 Nov 2026):
/// office Mon, Tue and Thu, early Tue 08:00, late Thu 19:00. Upper A, Run 1
/// and Upper B are logged done as prescribed, Thursday's full body is missed,
/// and the weight comes down about 0.5 kg a week.
@Suite struct Week2HybridCoachTests {
    let f = CoachFixture()

    private let answers = WeekAnswers(officeDays: [.monday, .tuesday, .thursday],
                                      earlyStarts: [.tuesday: TimeOfDay(hour: 8, minute: 0)],
                                      lateFinishes: [.thursday: TimeOfDay(hour: 19, minute: 0)])

    /// Sunday 29 Nov 2026, 18:00: when the owner shares and imports (A16, A17).
    private var sunday: Date { f.day(13, hour: 18) }
    private var weights: [WeightSample] { f.losing(0.5, to: 13) }

    /// Each strength item logged once, every set done as prescribed at its prescription.
    private func logged(_ sessionID: String, on day: Int, programme: Programme,
                        history: [SessionLog]) throws -> SessionLog {
        guard case let .strength(session) = try #require(programme.sessions[sessionID]) else {
            let at = f.day(day, hour: 7)
            return SessionLog(programmeID: programme.id, sessionID: sessionID, week: 2,
                              startedAt: at, finishedAt: at.addingTimeInterval(1_800))
        }
        var sets: [SetLog] = []
        for item in session.blocks.flatMap(\.items) {
            guard let rx = programme.prescription(for: item, week: 2, history: history) else { continue }
            for index in 0..<rx.sets {
                sets.append(SetLog(exercise: rx.exercise, setIndex: index, reps: rx.reps, seconds: rx.seconds,
                                   kg: rx.kg, asPrescribed: true, slowTempo: rx.slowTempo))
            }
        }
        let at = f.day(day, hour: 7)
        return SessionLog(programmeID: programme.id, sessionID: sessionID, week: 2, startedAt: at,
                          finishedAt: at.addingTimeInterval(2_400), recovery: .fine, sets: sets)
    }

    /// Mon Upper A, Tue Run 1, Sat Upper B; Thursday's full body never logged.
    private func week(_ p: Programme) throws -> [SessionLog] {
        var history: [SessionLog] = []
        for (session, day) in [("upper-a", 7), ("run-1", 8), ("upper-b", 12)] {
            history.append(try logged(session, on: day, programme: p, history: history))
        }
        return history
    }

    private func review(_ p: Programme, history: [SessionLog], blocks: [CoachBlock] = [],
                        at date: Date) throws -> CoachReview {
        try #require(CoachReview.make(programme: p, profile: f.profile(), history: history, weights: weights,
                                      blocks: blocks, now: date, calendar: f.calendar))
    }

    @Test func a5LoadsMoveAfterMondaysLog() throws {
        let p = try f.phase1()
        let history = try week(p)
        guard case let .strength(upperA) = try #require(p.sessions["upper-a"]) else { return }
        let bench = try #require(upperA.blocks.flatMap(\.items).first { $0.exercise == "dumbbell-bench-press" })
        let before = try #require(p.prescription(for: bench, week: 2, history: [], blocks: [], on: f.day(8), calendar: f.calendar))
        let after = try #require(p.prescription(for: bench, week: 2, history: Array(history.prefix(1)), blocks: [],
                                                on: f.day(8), calendar: f.calendar))
        #expect(before.reps == 8)
        #expect(after.reps == 9)
        #expect(after.step == .climb)
    }

    @Test func a13EveryDayOfTheWeekHasTheSameTargetAndBand() throws {
        let p = try f.phase1()
        let history = try week(p)
        for day in 7...13 {
            let r = try review(p, history: history, at: f.day(day, hour: 12))
            #expect(r.week == 2)
            #expect(r.calories.kcal == 2_000, "day \(day)")       // no checks in weeks 1–2
            #expect(r.calories.proteinG == 160)
            #expect(r.calories.dayBand == 1_850...2_150)
            #expect(r.flags.isEmpty)                              // nothing to tap
            #expect(r.droppedSessions.isEmpty)                    // all Fine: no reduced week
        }
    }

    /// The app's week2-hybrid fixture, with its fixed Health data (A12).
    private func fixtureHealth() throws -> FixedHealthReader {
        let url = contentRoot.deletingLastPathComponent()
            .appendingPathComponent("App/Testing/Fixtures/fixture-week2-hybrid.json")
        struct File: Decodable { let health: FixedHealthReader }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(File.self, from: Data(contentsOf: url)).health
    }

    @Test func a12FixtureHealthDataGivesTheTrendAndSteps() async throws {
        let health = try fixtureHealth()
        // The fixture is this suite's weight line, to the gram.
        #expect(health.weights.count == weights.count)
        for (fixed, line) in zip(health.weights, weights) {
            #expect(fixed.date == line.date)
            #expect(abs(fixed.kg - line.kg) < 0.005)
        }
        let samples = try await health.weights(from: f.day(-14), to: f.day(14))
        let trend = try #require(WeightTrend.make(samples: samples, endingOn: sunday, calendar: f.calendar))
        #expect(trend.daysWeighed == 7)
        #expect(abs((trend.changeKg ?? 0) + 0.5) < 0.01) // down about 0.5 kg on the week before
        let steps = StepsSummary.make(days: try await health.dailySteps(from: f.day(6), to: f.day(14)),
                                      today: sunday, calendar: f.calendar)
        #expect(steps.today == 6_500)
        #expect(steps.sevenDayAverage != nil)
    }

    @Test func a13MealsEveryDayArePreTickedAndInsideTheBand() throws {
        let p = try f.phase1()
        let lib = try ContentLibrary.load(from: contentRoot)
        let fixed = try fixtureHealth().weights
        let plan = MealPlan.week(monday: f.day(7), content: lib.nutrition, lunchOrders: lib.lunchOrders.orders,
                                 answers: answers, programmeID: p.id, kcalTarget: 2_000, calendar: f.calendar)
        #expect(plan.days.count == 7)
        for day in plan.days {
            let r = try #require(CoachReview.make(programme: p, profile: f.profile(), history: [], weights: fixed,
                                                  blocks: [], now: day.date.addingTimeInterval(12 * 3_600),
                                                  calendar: f.calendar))
            #expect(day.target.kcal == r.calories.kcal, "\(day.weekday)")
            #expect(day.target.kcalMin...day.target.kcalMax == r.calories.dayBand, "\(day.weekday)")
            #expect(day.meals.allSatisfy { $0.ticked }, "\(day.weekday)")  // nothing to tap if eaten as planned
            #expect(day.withinBand, "\(day.weekday): \(day.kcal) kcal, \(day.protein) g")
            // Advisor (17 Nov): 150 g a day is the pass line; about 160 is the aim.
            #expect(day.protein >= day.target.proteinMin, "\(day.weekday): \(day.protein) g")
            let office = answers.officeDays.contains(day.weekday)
            #expect((day.meal(.lunch)?.isOfficeLunch ?? false) == office, "\(day.weekday)")
        }
        // ...and the week's planned protein averages at least 155 g a day.
        let average = Double(plan.days.reduce(0) { $0 + $1.protein }) / Double(plan.days.count)
        #expect(average >= 155, "weekly average \(average) g")
    }

    @Test func a16SundaySummaryCarriesTheWeek() throws {
        let p = try f.phase1()
        let history = try week(p)
        let text = try #require(CoachSummary.text(programme: p, profile: f.profile(), history: history,
                                                  weights: weights, blocks: [], now: sunday, calendar: f.calendar))
        #expect(text.hasPrefix("HealthCoach · Check-in\nSun 29 Nov 2026 · Cut and rebuild, week 2 of 6"))
        #expect(text.contains("- Target: 2,000 kcal and 160 g protein a day (starting target)"))
        #expect(text.contains("- Recovery (last 14 days): 2 Fine, 0 Sore"))
        #expect(text.contains("  - dumbbell-bench-press: 10 kg × 9 reps"))
        #expect(text.contains(CoachImport.beginMarker))
        // Missed full body shows as a gap, not as anything to do.
        #expect(text.contains("- Sessions done: 3 of 8 planned"))
    }

    @Test func a17AValidBlockChangesNextWeekAndABadOneLeavesItAlone() throws {
        let p = try f.phase1()
        let profile = f.profile()
        let history = try week(p)
        let nextMonday = f.monday(3)
        let reply = """
            Solid week. Skip full body next week while you settle in, and nudge the bench.
            \(CoachImport.beginMarker)
            {"format": "healthcoach-coach-block", "schemaVersion": 1, "note": "Two uppers and two runs next week.",
             "dailyKcal": 2100, "dropSessions": ["full-body"],
             "loads": [{"exercise": "dumbbell-bench-press", "kg": 12}]}
            \(CoachImport.endMarker)
            """

        let baseline = try review(p, history: history, at: nextMonday)
        let basePlan = WeekPlanner.plan(weekStarting: nextMonday, programme: p, profile: profile, answers: answers,
                                        dropping: baseline.droppedSessions, calendar: f.calendar)
        #expect(basePlan.days.contains { $0.session?.sessionID == "full-body" })

        // Valid: next week changes.
        let good = CoachImport.importing(reply, into: [], programme: p, profile: profile, now: sunday, calendar: f.calendar)
        #expect(good.message == "Imported. The new plan starts tomorrow.")
        let changed = try review(p, history: history, blocks: good.blocks, at: nextMonday)
        #expect(changed.calories.kcal == 2_100)
        #expect(changed.block?.note == "Two uppers and two runs next week.")
        let plan = WeekPlanner.plan(weekStarting: nextMonday, programme: p, profile: profile, answers: answers,
                                    dropping: changed.droppedSessions, calendar: f.calendar)
        #expect(!plan.days.contains { $0.session?.sessionID == "full-body" })
        #expect(plan.days.contains { $0.session?.sessionID == "upper-a" })
        #expect(plan.day(.wednesday)?.session == nil) // basketball day untouched
        guard case let .strength(upperA) = try #require(p.sessions["upper-a"]) else { return }
        let bench = try #require(upperA.blocks.flatMap(\.items).first { $0.exercise == "dumbbell-bench-press" })
        #expect(p.prescription(for: bench, week: 3, history: history, blocks: good.blocks, on: nextMonday,
                               calendar: f.calendar)?.kg == 12)
        // The player shows it too, and without blocks it's the logged progression.
        func benchKg(_ blocks: [CoachBlock]) -> Double? {
            WorkoutScript.make(sessionID: "upper-a", programme: p, week: 3, history: history, blocks: blocks,
                               on: nextMonday, calendar: f.calendar)?
                .sets.first { $0.exercise == "dumbbell-bench-press" }?.kg
        }
        #expect(benchKg(good.blocks) == 12)
        #expect(benchKg([]) != 12)

        // Bad: rejected plainly, and next week is exactly the baseline.
        let bad = CoachImport.importing(reply.replacingOccurrences(of: "\"schemaVersion\": 1", with: "\"schemaVersion\": 2"),
                                        into: [], programme: p, profile: profile, now: sunday, calendar: f.calendar)
        #expect(bad.blocks.isEmpty)
        #expect(bad.message.hasSuffix("Your plan hasn't changed."))
        #expect(try review(p, history: history, blocks: bad.blocks, at: nextMonday) == baseline)
    }
}
