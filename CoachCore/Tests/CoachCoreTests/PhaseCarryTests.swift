import Foundation
import Testing
@testable import CoachCore

/// Board C6: weeks count on across phases (plan week 7 is Phase 2's week 1,
/// 15 is Phase 3's), and loads carry over: Phase 1 into 2 as they were, the
/// maintenance break (plan weeks 13–14) holds them, and Phase 3's new 6–10
/// range starts at the carried weight, never a step up.
@Suite struct PhaseCarryTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    /// Monday of plan week 1.
    private var start: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 16))! }

    /// Wednesday of `planWeek`, 07:00.
    private func day(inPlanWeek planWeek: Int) -> Date {
        calendar.date(byAdding: .day, value: 7 * (planWeek - 1) + 2, to: start)!.addingTimeInterval(7 * 3600)
    }

    private func library() throws -> ContentLibrary { try ContentLibrary.load(from: contentRoot) }

    // MARK: Weeks

    @Test func eachPlanWeekHasItsPhaseAndOwnWeek() throws {
        let lib = try library()
        for planWeek in 1...20 {
            let date = day(inPlanWeek: planWeek)
            let programme = try #require(lib.programme(on: date, start: start, calendar: calendar))
            let expected = planWeek <= 6 ? "phase-1" : planWeek <= 14 ? "phase-2" : "phase-3"
            #expect(programme.id == expected, "plan week \(planWeek)")
            let planned = programme.plannedDay(on: date, start: start, calendar: calendar)
            #expect(planned.week == planWeek - programme.planWeekOffset, "plan week \(planWeek)")
            #expect(!planned.heldAtLastWeek)
        }
        // The boundaries the HoE named: week 7 is Phase 2 week 1, week 15 is Phase 3 week 1.
        #expect(lib.programme(on: day(inPlanWeek: 7), start: start, calendar: calendar)?
            .plannedDay(on: day(inPlanWeek: 7), start: start, calendar: calendar).week == 1)
        #expect(lib.programme(on: day(inPlanWeek: 15), start: start, calendar: calendar)?
            .plannedDay(on: day(inPlanWeek: 15), start: start, calendar: calendar).week == 1)
        // After week 20, Phase 3 holds at its last week (E13).
        let after = try #require(lib.programme(on: day(inPlanWeek: 22), start: start, calendar: calendar))
        #expect(after.id == "phase-3")
        let held = after.plannedDay(on: day(inPlanWeek: 22), start: start, calendar: calendar)
        #expect(held.week == 6 && held.heldAtLastWeek)
        // Before its own start, a later phase plans nothing.
        let phase2 = try #require(lib.programmes["phase-2"])
        #expect(phase2.plannedDay(on: day(inPlanWeek: 3), start: start, calendar: calendar).entry == .beforeStart)
    }

    /// QA: with Phases 2 and 3 loaded, maintenance is still weeks 13–14 and the week count never resets.
    @Test func maintenanceStaysInWeeks13And14AndTheCountNeverResets() throws {
        let lib = try library()
        for planWeek in 1...20 {
            let date = day(inPlanWeek: planWeek)
            #expect(CalorieRules.week(of: date, start: start, calendar: calendar) == planWeek)
            let programme = try #require(lib.programme(on: date, start: start, calendar: calendar))
            var profile = Profile()
            profile.confirmed = true
            profile.programme.programmeID = programme.id
            profile.programme.startDate = start
            let review = try #require(CoachReview.make(programme: programme, profile: profile, history: [],
                                                       weights: [], blocks: [], now: date, calendar: calendar))
            #expect(review.week == planWeek, "\(programme.id) at plan week \(planWeek)")
            let own = try #require(programme.plannedDay(on: date, start: start, calendar: calendar).week)
            #expect(CalorieRules.isMaintenance(week: planWeek) == (planWeek == 13 || planWeek == 14))
            #expect(programme.holdsLoads(week: own) == CalorieRules.isMaintenance(week: planWeek),
                    "load hold and calorie maintenance agree at plan week \(planWeek)")
        }
    }

    @Test func thePhasesFollowOnWeekForWeek() throws {
        let lib = try library()
        #expect(lib.phases.map(\.planWeeks) == [1...6, 7...14, 15...20])
        #expect(lib.programmes["phase-3"]?.earlierPhases?.map(\.id) == ["phase-1", "phase-2"])
        #expect(lib.programmes["phase-1"]?.earlierPhases?.isEmpty == true)
    }

    // MARK: Loads

    /// Every strength session of plan weeks `1...through`, all done as
    /// prescribed, each logged under the programme in force that week.
    private func allDone(through planWeek: Int, _ lib: ContentLibrary) throws -> [SessionLog] {
        var logs: [SessionLog] = []
        for week in 1...planWeek {
            for offset in 0..<7 {
                let date = calendar.date(byAdding: .day, value: 7 * (week - 1) + offset, to: start)!
                    .addingTimeInterval(7 * 3600)
                let programme = try #require(lib.programme(on: date, start: start, calendar: calendar))
                let planned = programme.plannedDay(on: date, start: start, calendar: calendar)
                guard case let .session(id, .strength) = planned.entry, let own = planned.week,
                      let script = WorkoutScript.make(sessionID: id, programme: programme, week: own, history: logs)
                else { continue }
                var log = SessionLog(programmeID: programme.id, sessionID: id, week: own, startedAt: date,
                                     finishedAt: date.addingTimeInterval(45 * 60))
                log.sets = script.sets.map { $0.prescribedLog() }
                logs.append(log)
            }
        }
        return logs
    }

    private func bench(_ programme: Programme) throws -> StrengthItem {
        try #require(programme.strengthItem(continuing: StrengthItem.named("dumbbell-bench-press", in: programme)))
    }

    @Test func phase1CarriesIntoPhase2AsItWas() throws {
        let lib = try library()
        let p1 = try #require(lib.programmes["phase-1"]), p2 = try #require(lib.programmes["phase-2"])
        let history = try allDone(through: 6, lib)
        // What Phase 1 would have asked for next, had it gone on.
        let next = try #require(p1.prescription(for: bench(p1), week: 6, history: history))
        let week7 = try #require(p2.prescription(for: bench(p2), week: 1, history: history))
        #expect(week7.kg == next.kg && week7.reps == next.reps, "P2 week 1 \(week7) vs P1 next \(next)")
        let firstKg = try #require(p1.prescription(for: bench(p1), week: 1, history: [])?.kg)
        #expect((week7.kg ?? 0) > firstKg, "six all-done weeks moved the bench up")
    }

    @Test func theMaintenanceBreakHoldsTheLoadAndPhase3StartsThereAtTheBottomOfItsRange() throws {
        let lib = try library()
        let p2 = try #require(lib.programmes["phase-2"]), p3 = try #require(lib.programmes["phase-3"])
        let item2 = try bench(p2), item3 = try bench(p3)

        // Plan week 12 (Phase 2 week 6) done: the weight it was done at.
        let toWeek12 = try allDone(through: 12, lib)
        let week12Kg = try #require(toWeek12.last { $0.sets.contains { $0.exercise == item2.exercise } }?
            .sets.first { $0.exercise == item2.exercise }?.kg)
        // Weeks 13–14 (Phase 2 weeks 7–8, holdLoads): the same weight, all done or not.
        let week13 = try #require(p2.prescription(for: item2, week: 7, history: toWeek12))
        #expect(week13.kg == week12Kg, "\(week13)")
        let toWeek14 = try allDone(through: 14, lib)
        for log in toWeek14 where log.programmeID == "phase-2" && log.week >= 7 {
            for set in log.sets where set.exercise == item2.exercise { #expect(set.kg == week12Kg) }
        }
        let week14 = try #require(p2.prescription(for: item2, week: 8, history: toWeek14))
        #expect(week14.kg == week12Kg)

        // Week 15 (Phase 3 week 1): the held weight, bottom of the new 6–10 range, no step up.
        let week15 = try #require(p3.prescription(for: item3, week: 1, history: toWeek14))
        #expect(item3.reps == IntRange(min: 6, max: 10))
        #expect(week15.kg == week12Kg)
        #expect(week15.reps == 6)
        #expect(week15.step == .carried)

        // Then normal progression: an all-done week 15 climbs a rep.
        let toWeek15 = try allDone(through: 15, lib)
        let week16 = try #require(p3.prescription(for: item3, week: 2, history: toWeek15))
        #expect(week16.kg == week12Kg && week16.reps == 7 && week16.step == .climb, "\(week16)")
    }

    @Test func aProgrammeOnItsOwnReplaysEveryLogAsBefore() throws {
        // No earlier phases (a programme decoded alone): the pre-C6 behaviour.
        let lib = try library()
        var p2 = try #require(lib.programmes["phase-2"])
        p2.earlierPhases = nil
        let history = try allDone(through: 6, lib)
        let alone = try #require(p2.prescription(for: bench(p2), week: 1, history: history))
        #expect(alone.step != .carried)
    }
}

extension StrengthItem {
    /// The programme's item for `exercise` (tests only).
    static func named(_ exercise: String, in programme: Programme) -> StrengthItem {
        programme.strengthItems.first { $0.exercise == exercise }!
    }
}

/// HoE: the alarm horizon plans each day from the phase in force that day, so
/// the Sunday of week 6 sets Monday of week 7 (and on) from Phase 2.
@Suite struct PhaseAlarmTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func sundayOfWeek6PlansMondayOfWeek7FromPhase2() throws {
        let lib = try ContentLibrary.load(from: contentRoot)
        var profile = Profile()
        profile.confirmed = true
        profile.programme.startDate = at(2026, 11, 16)          // plan week 1
        profile.programme.confirmedOn = at(2026, 11, 15, 18)
        let now = at(2026, 12, 27, 18)                           // Sunday of week 6
        let p1 = try #require(lib.programme(for: profile, on: now, calendar: calendar))
        #expect(p1.id == "phase-1")
        let p2 = try #require(lib.programmes["phase-2"])
        let alarms = AlarmSchedule.make(now: now, programme: p1, profile: profile, answers: { _ in WeekAnswers() },
                                        programmeOn: { lib.programme(for: profile, on: $0, calendar: calendar) },
                                        calendar: calendar)

        // Every alarm from Monday 28 Dec is exactly Phase 2's for that day.
        let monday = at(2026, 12, 28)
        let phase2Week = WeekPlanner.plan(weekStarting: monday, programme: p2, profile: profile,
                                          answers: WeekAnswers(), now: now, calendar: calendar)
        let expected = phase2Week.days.compactMap { AlarmSchedule.alarm(for: $0, programme: p2, calendar: calendar) }
        let got = alarms.filter { $0.fireDate >= monday && $0.fireDate < at(2027, 1, 4) }
        #expect(!expected.isEmpty)
        #expect(got == expected)
        let mondayAlarm = try #require(got.first { calendar.isDate($0.fireDate, inSameDayAs: monday) })
        #expect(p2.plannedDay(on: monday, start: profile.programme.startDate!, calendar: calendar).week == 1)
        #expect(mondayAlarm == expected.first { calendar.isDate($0.fireDate, inSameDayAs: monday) })
    }
}
