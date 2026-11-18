import Foundation
import Testing
@testable import CoachCore

/// Board C1: the coach loop end to end. Four weeks of fixture weigh-ins and
/// session logs (Mon 16 Nov – Sun 13 Dec 2026) go in; out come the weekly
/// calorie target, next Monday's meal plan, and Thursday's loads in the
/// player. A Claude reply imported on the Sunday evening changes them; a reply
/// that breaks any import limit (QA-R3) changes none of them.
@Suite struct CoachLoopTests {
    let f = CoachFixture()

    /// Office Mon, Tue and Thu, as in the Gate 1 hybrid week.
    let answers = WeekAnswers(officeDays: [.monday, .tuesday, .thursday])

    /// Sunday of week 4, 18:00: the owner shares the summary and imports the reply.
    var sunday: Date { f.day(27, hour: 18) }
    /// Monday of week 5: next week's plan.
    var nextMonday: Date { f.monday(5, hour: 0) }
    /// Thursday of week 5, 07:00: full body, with the goblet squat (only in that session).
    var thursday: Date { f.day(31, hour: 7) }

    // MARK: - Fixture: four weeks of logs

    /// Upper A Mon, Run 1 Tue, Full body Thu, Upper B Sat, weeks 1–4, each set
    /// done as prescribed. One Sore answer (week 3 Upper B) and the rest Fine,
    /// so no reduced week.
    func fourWeeks(_ p: Programme) throws -> [SessionLog] {
        var history: [SessionLog] = []
        for week in 1...4 {
            for (session, weekday) in [("upper-a", 0), ("run-1", 1), ("full-body", 3), ("upper-b", 5)] {
                let day = (week - 1) * 7 + weekday
                let sore = week == 3 && session == "upper-b"
                history.append(try log(session, week: week, day: day, programme: p, history: history,
                                       recovery: sore ? .sore : .fine))
            }
        }
        return history
    }

    func log(_ sessionID: String, week: Int, day: Int, programme: Programme, history: [SessionLog],
             recovery: RecoveryCheck) throws -> SessionLog {
        let at = f.day(day, hour: 7)
        guard case let .strength(session) = try #require(programme.sessions[sessionID]) else {
            return SessionLog(programmeID: programme.id, sessionID: sessionID, week: week,
                              startedAt: at, finishedAt: at.addingTimeInterval(1_800))
        }
        var sets: [SetLog] = []
        for item in session.blocks.flatMap(\.items) {
            guard let rx = programme.prescription(for: item, week: week, history: history) else { continue }
            for index in 0..<rx.sets {
                sets.append(SetLog(exercise: rx.exercise, setIndex: index, reps: rx.reps, seconds: rx.seconds,
                                   kg: rx.kg, asPrescribed: true, slowTempo: rx.slowTempo))
            }
        }
        return SessionLog(programmeID: programme.id, sessionID: sessionID, week: week, startedAt: at,
                          finishedAt: at.addingTimeInterval(2_400), recovery: recovery, sets: sets)
    }

    // MARK: - What the app shows

    struct Shown: Equatable {
        let review: CoachReview
        let meals: MealPlan
        let thursday: WorkoutScript?
    }

    /// Next week as the app shows it: the review on `at`, the coached meal plan
    /// for the week starting `monday`, and Thursday's full body.
    func shown(_ p: Programme, history: [SessionLog], weights: [WeightSample], blocks: [CoachBlock],
               at: Date, monday: Date, thursday: Date) throws -> Shown {
        let lib = try ContentLibrary.load(from: contentRoot)
        let review = try #require(CoachReview.make(programme: p, profile: f.profile(), history: history,
                                                   weights: weights, blocks: blocks, now: at, calendar: f.calendar))
        let meals = MealPlan.coached(monday: monday, now: sunday, content: lib.nutrition,
                                     lunchOrders: lib.lunchOrders.orders, answers: answers, programme: p,
                                     profile: f.profile(), history: history, weights: weights, blocks: blocks,
                                     calendar: f.calendar)
        let week = try #require(p.plannedDay(on: thursday, start: f.start, calendar: f.calendar).week)
        let script = WorkoutScript.make(sessionID: "full-body", programme: p, week: week, history: history,
                                        blocks: blocks, on: thursday, calendar: f.calendar)
        return Shown(review: review, meals: meals, thursday: script)
    }

    func gobletKg(_ script: WorkoutScript?) -> Double? {
        script?.sets.first { $0.exercise == "dumbbell-goblet-squat" }?.kg
    }

    func reply(_ fields: String) -> String {
        """
        Good four weeks.
        \(CoachImport.beginMarker)
        {"format": "healthcoach-coach-block", "schemaVersion": 1\(fields.isEmpty ? "" : ", " + fields)}
        \(CoachImport.endMarker)
        """
    }

    // MARK: - Calories: engine steps

    /// kg lost a week, and the target in force on the Monday of weeks 1–5.
    static let trends: [(rate: Double, kcal: [Int])] = [
        (0.1, [2_000, 2_000, 1_900, 1_850, 1_850]),   // slow: down 100, then only 50 to the floor, then held
        (0.5, [2_000, 2_000, 2_000, 2_000, 2_000]),   // on track
        (1.5, [2_000, 2_000, 2_100, 2_200, 2_200]),   // fast: up 100 a week to the ceiling, then held
    ]

    @Test(arguments: trends.indices)
    func targetMovesAtMost100AWeekAndNeverPastTheFloors(_ index: Int) throws {
        let (rate, expected) = Self.trends[index]
        let p = try f.phase1()
        let history = try fourWeeks(p)
        let weights = f.losing(rate, to: 34)
        var previous: Int?
        for week in 1...5 {
            var mondayKcal: Int?
            for offset in 0..<7 {
                let day = (week - 1) * 7 + offset
                let r = try #require(CoachReview.make(programme: p, profile: f.profile(), history: history,
                                                      weights: weights, blocks: [], now: f.day(day, hour: 12),
                                                      calendar: f.calendar))
                let kcal = r.calories.kcal
                // Floors (Advisor): 1,850 for the week, and no planned day under 1,700.
                #expect(CalorieRules.cutBand.contains(kcal), "rate \(rate), day \(day): \(kcal)")
                #expect(r.calories.dayBand.lowerBound >= CalorieRules.dayFloorKcal)
                // Only the Monday check moves it.
                if let mondayKcal { #expect(kcal == mondayKcal, "rate \(rate), day \(day)") } else { mondayKcal = kcal }
            }
            let kcal = try #require(mondayKcal)
            #expect(kcal == expected[week - 1], "rate \(rate), week \(week)")
            if let previous { #expect(abs(kcal - previous) <= CalorieRules.stepKcal, "rate \(rate), week \(week)") }
            previous = kcal
        }
    }

    @Test(arguments: trends.indices)
    func nextMondaysMealsUseTheNewTarget(_ index: Int) throws {
        let (rate, expected) = Self.trends[index]
        let p = try f.phase1()
        let history = try fourWeeks(p)
        let weights = f.losing(rate, to: 27)
        let s = try shown(p, history: history, weights: weights, blocks: [], at: nextMonday,
                          monday: nextMonday, thursday: thursday)
        #expect(s.review.calories.kcal == expected[4])
        #expect(s.meals.days.count == 7)
        for day in s.meals.days {
            #expect(day.target.kcal == s.review.calories.kcal, "\(day.weekday)")
            #expect(day.target.kcalMin...day.target.kcalMax == s.review.calories.dayBand, "\(day.weekday)")
            #expect(day.kcal >= CalorieRules.dayFloorKcal, "\(day.weekday): \(day.kcal)")
            #expect(day.withinBand, "rate \(rate) \(day.weekday): \(day.kcal) kcal, \(day.protein) g")
        }
    }

    // MARK: - Summary: meals and recovery, as averages

    @Test func summaryCarriesMealAdherenceAndRecoveryAsCountsOnly() throws {
        let p = try f.phase1()
        let history = try fourWeeks(p)
        let weights = f.losing(0.5, to: 27)
        let lib = try ContentLibrary.load(from: contentRoot)
        func plan(_ monday: Date) -> MealPlan {
            MealPlan.coached(monday: monday, now: sunday, content: lib.nutrition, lunchOrders: lib.lunchOrders.orders,
                             answers: answers, programme: p, profile: f.profile(), history: history,
                             weights: weights, blocks: [], calendar: f.calendar)
        }
        // Skipped Tuesday's lunch and Friday's snack.
        let skipped: Set<String> = ["\(Weekday.tuesday)|lunch", "\(Weekday.friday)|snack"]
        let meals = try #require(MealAdherence.lastSevenDays(
            now: sunday, plan: plan, isTicked: { day, meal in !skipped.contains("\(day.weekday)|\(meal.id)") },
            calendar: f.calendar))
        #expect(meals.days == 7)
        #expect(meals.eaten == meals.planned - 2)
        #expect(meals.socialMeals == nil)
        #expect(meals.averageKcal > 1_700 && meals.averageKcal < 2_150)

        let text = try #require(CoachSummary.text(programme: p, profile: f.profile(), history: history,
                                                  weights: weights, meals: meals, blocks: [], now: sunday,
                                                  calendar: f.calendar))
        #expect(text.contains("- Meals (last 7 days): \(meals.eaten) of \(meals.planned) planned meals eaten as planned; about \(CoachText.thousands(meals.averageKcal)) kcal and \(meals.averageProteinG) g protein a day from those"))
        // Weeks 3–4: six strength sessions answered, one Sore; runs don't ask.
        #expect(text.contains("- Recovery (last 14 days): 5 Fine, 1 Sore"))
        #expect(!text.contains("Social meals"))
        // Averages only: no meal or recipe names, no day-by-day lines.
        for day in plan(f.monday(4)).days {
            for meal in day.meals { #expect(!text.contains(meal.name), "\(meal.name)") }
        }
        #expect(!text.contains("Tuesday") && !text.contains("Friday"))

        // C4's counter, when it lands, adds one line.
        let withSocial = MealAdherence(days: 7, planned: 28, eaten: 26, averageKcal: 1_950, averageProteinG: 158,
                                       socialMeals: 1)
        let social = try #require(CoachSummary.text(programme: p, profile: f.profile(), history: history,
                                                    weights: weights, meals: withSocial, blocks: [], now: sunday,
                                                    calendar: f.calendar))
        #expect(social.contains("- Social meals: 1 (allowance 2 a week)"))
    }

    // MARK: - Import: accepted

    @Test func anAcceptedImportChangesCaloriesMealsAndThursdaysLoad() throws {
        let p = try f.phase1()
        let profile = f.profile()
        let history = try fourWeeks(p)
        let weights = f.losing(0.5, to: 27)
        let baseline = try shown(p, history: history, weights: weights, blocks: [], at: nextMonday,
                                 monday: nextMonday, thursday: thursday)
        let baseKg = try #require(gobletKg(baseline.thursday))
        let newKg = baseKg + 2 * p.loadStepKg
        try #require(newKg <= p.dumbbellLimitKg)

        // +150 kcal: an in-band import may move further than the engine's 100 a week (QA-R3).
        let text = reply("\"note\": \"Eat a bit more and push the squat.\", \"dailyKcal\": 2150, \"loads\": [{\"exercise\": \"dumbbell-goblet-squat\", \"kg\": \(CoachText.number(newKg))}]")
        let outcome = CoachImport.importing(text, into: [], programme: p, profile: profile, now: sunday, calendar: f.calendar)
        #expect(outcome.error == nil, "\(outcome.message)")
        #expect(outcome.message == "Imported. The new plan starts tomorrow.")

        let after = try shown(p, history: history, weights: weights, blocks: outcome.blocks, at: nextMonday,
                              monday: nextMonday, thursday: thursday)
        #expect(after.review.calories.kcal == 2_150)
        #expect(after.review.calories.reason == .imported)
        #expect(after.meals != baseline.meals)
        for day in after.meals.days {
            #expect(day.target.kcal == 2_150, "\(day.weekday)")
            #expect(day.withinBand, "\(day.weekday): \(day.kcal) kcal, \(day.protein) g")
        }
        #expect(gobletKg(after.thursday) == newKg)
        #expect(baseKg != newKg)
        // The rest of Thursday is as it was.
        #expect(after.thursday?.sets.filter { $0.exercise != "dumbbell-goblet-squat" }
            == baseline.thursday?.sets.filter { $0.exercise != "dumbbell-goblet-squat" })

        // The import is the starting point; the engine steps on from it no more than 100 a week.
        let later = f.losing(0.1, to: 55)
        var previous = 2_150
        for week in 6...8 {
            let r = try #require(CoachReview.make(programme: p, profile: profile, history: history, weights: later,
                                                  blocks: outcome.blocks, now: f.monday(week), calendar: f.calendar))
            #expect(abs(r.calories.kcal - previous) <= CalorieRules.stepKcal, "week \(week)")
            #expect(r.calories.kcal >= CalorieRules.cutBand.lowerBound)
            previous = r.calories.kcal
        }
    }

    // MARK: - Import: every limit refused, nothing changes (QA-R3)

    /// One reply per import limit, and the week it's imported in (the Sunday
    /// before `week`). Maintenance limits are checked in week 13.
    static let refused: [(name: String, week: Int, fields: String)] = [
        ("calories under the cut band", 5, "\"dailyKcal\": 1800"),
        ("calories over the cut band", 5, "\"dailyKcal\": 2300"),
        ("calories under the maintenance band", 13, "\"dailyKcal\": 2200"),
        ("calories over the maintenance band", 13, "\"dailyKcal\": 2700"),
        ("protein under 140", 5, "\"proteinG\": 139"),
        ("protein over 180", 5, "\"proteinG\": 181"),
        ("load over 24 kg", 5, "\"loads\": [{\"exercise\": \"dumbbell-goblet-squat\", \"kg\": 26}]"),
        ("load between dumbbell steps", 5, "\"loads\": [{\"exercise\": \"dumbbell-goblet-squat\", \"kg\": 15}]"),
        ("fewer than 2 strength sessions", 5, "\"dropSessions\": [\"upper-a\", \"upper-b\"]"),
        ("adding a session", 5, "\"addSessions\": [\"upper-c\"]"),
        ("moving a session", 5, "\"moveSessions\": {\"full-body\": \"friday\"}"),
        ("dropping a fixed event", 5, "\"dropSessions\": [\"basketball\"]"),
        ("dropping a session that doesn't exist", 5, "\"dropSessions\": [\"upper-c\"]"),
        // One bad field spoils a block that is otherwise fine: nothing in it applies.
        ("good calories with a bad load", 5, "\"dailyKcal\": 2100, \"loads\": [{\"exercise\": \"dumbbell-goblet-squat\", \"kg\": 26}]"),
    ]

    @Test(arguments: refused.indices)
    func aReplyOutsideAnyLimitChangesNothing(_ index: Int) throws {
        let (name, week, fields) = Self.refused[index]
        let p = try f.phase1()
        let profile = f.profile()
        let history = try fourWeeks(p)
        let weights = f.losing(0.5, to: week * 7)
        let importedAt = f.day((week - 1) * 7 - 1, hour: 18)
        let monday = f.monday(week, hour: 0)
        let thursday = f.day((week - 1) * 7 + 3, hour: 7)
        let baseline = try shown(p, history: history, weights: weights, blocks: [], at: monday,
                                 monday: monday, thursday: thursday)

        let outcome = CoachImport.importing(reply(fields), into: [], programme: p, profile: profile,
                                            now: importedAt, calendar: f.calendar)
        #expect(outcome.accepted == nil, "\(name)")
        #expect(outcome.blocks.isEmpty, "\(name)")
        #expect(outcome.message.hasSuffix("Your plan hasn't changed."), "\(name): \(outcome.message)")

        let after = try shown(p, history: history, weights: weights, blocks: outcome.blocks, at: monday,
                              monday: monday, thursday: thursday)
        #expect(after.review == baseline.review, "\(name): calories or sessions changed")
        #expect(after.meals == baseline.meals, "\(name): meals changed")
        #expect(after.thursday == baseline.thursday, "\(name): Thursday's loads changed")
    }

    @Test func anInBandMaintenanceImportIsAccepted() throws {
        let p = try f.phase1()
        let history = try fourWeeks(p)
        let weights = f.losing(0.5, to: 91)
        let outcome = CoachImport.importing(reply("\"dailyKcal\": 2500"), into: [], programme: p, profile: f.profile(),
                                            now: f.day(83, hour: 18), calendar: f.calendar)
        #expect(outcome.error == nil, "\(outcome.message)")
        let r = try #require(CoachReview.make(programme: p, profile: f.profile(), history: history, weights: weights,
                                              blocks: outcome.blocks, now: f.monday(13), calendar: f.calendar))
        #expect(r.calories.kcal == 2_500)
    }

    // MARK: - Checkpoints across phases (QA-R3)

    /// A stand-in for the phase 2 and 3 files (board C5): phase 1's sessions
    /// under another id, phase and length.
    func standIn(id: String, phase: Int, weeks: Int) throws -> Programme {
        let url = contentRoot.appendingPathComponent("programmes/phase-1.json")
        var json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let schedule = try #require(json["schedule"] as? [[String: Any]])
        json["id"] = id
        json["phase"] = phase
        json["weeks"] = weeks
        json["schedule"] = (1...weeks).map { week -> [String: Any] in
            var entry = schedule[min(week, schedule.count) - 1]
            entry["week"] = week
            return entry
        }
        let data = try JSONSerialization.data(withJSONObject: json)
        return try Programme.decode(data, file: "\(id).json")
    }

    @Test func checkpointsStayAtWeeks6_14And20WhenLaterPhasesLoad() throws {
        let phases = [try f.phase1(), try standIn(id: "phase-2", phase: 2, weeks: 8),
                      try standIn(id: "phase-3", phase: 3, weeks: 6)]
        let weights = f.losing(0.5, to: 150)
        for (index, (checkpointWeek, programme)) in zip(CoachReview.checkpointWeeks, phases).enumerated() {
            var profile = f.profile()
            profile.programme.programmeID = programme.id   // the phase moves on; the start date doesn't
            #expect(profile.programme.startDate == f.start)
            let opens = (checkpointWeek - 1) * 7 + 5      // Saturday of the checkpoint week
            func review(_ day: Int) throws -> CoachReview {
                try #require(CoachReview.make(programme: programme, profile: profile, history: [], weights: weights,
                                              blocks: [], now: f.day(day, hour: 12), calendar: f.calendar))
            }
            let before = try review(opens - 1)
            #expect(before.week == checkpointWeek, "\(programme.id)")
            #expect(!before.flags.contains(.checkpoint(index + 1)), "\(programme.id)")
            let due = try review(opens)
            #expect(due.flags.contains(.checkpoint(index + 1)), "\(programme.id): \(due.flags)")
            // Still due through the next week, then gone.
            #expect(try review(opens + 8).flags.contains(.checkpoint(index + 1)), "\(programme.id)")
            #expect(!(try review(checkpointWeek * 7 + 7).flags.contains(.checkpoint(index + 1))), "\(programme.id)")
        }
    }
}
