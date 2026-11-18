import Foundation
import Testing
@testable import CoachCore

/// Board N8 (Advisor A2): loads ease after 10+ days without strength work,
/// then rebuild to where they were; the player says why; normal weeks don't change.
@Suite struct ReturnEasingTests {
    let f = CoachFixture()
    let loop = CoachLoopTests()

    /// Upper A, Run 1, Full body and Upper B for `weeks` weeks, then nothing.
    func logged(weeks: Int, _ p: Programme) throws -> [SessionLog] {
        try loop.fourWeeks(p).filter { $0.week <= weeks }
    }

    func bench(_ p: Programme) throws -> StrengthItem {
        guard case let .strength(s) = try #require(p.sessions["upper-a"]) else { throw CancellationError() }
        return try #require(s.blocks.flatMap(\.items).first { $0.exercise == "dumbbell-bench-press" })
    }

    func rx(_ p: Programme, _ history: [SessionLog], day: Int) throws -> Prescription {
        let week = try #require(p.plannedDay(on: f.day(day), start: f.start, calendar: f.calendar).week)
        return try #require(p.prescription(for: try bench(p), week: week, history: history, blocks: [],
                                           on: f.day(day, hour: 7), calendar: f.calendar))
    }

    /// Logs Upper A on `day` exactly as the app prescribes it then (eased or not).
    func logUpperA(_ p: Programme, _ history: [SessionLog], day: Int) throws -> [SessionLog] {
        let week = try #require(p.plannedDay(on: f.day(day), start: f.start, calendar: f.calendar).week)
        let script = try #require(WorkoutScript.make(sessionID: "upper-a", programme: p, week: week, history: history,
                                                     on: f.day(day, hour: 7), calendar: f.calendar))
        var counts: [String: Int] = [:]
        let sets = script.sets.map { step -> SetLog in
            let index = counts[step.exercise, default: 0]
            counts[step.exercise] = index + 1
            let reps: Int? = switch step.kind {
            case let .reps(target), let .perSide(target): target
            case let .negatives(reps, _): reps
            case .hold: nil
            }
            let seconds: Int? = if case let .hold(s) = step.kind { s } else { nil }
            return SetLog(exercise: step.exercise, setIndex: index, reps: reps, seconds: seconds, kg: step.kg,
                          asPrescribed: true, slowTempo: step.slowTempo)
        }
        let at = f.day(day, hour: 7)
        return history + [SessionLog(programmeID: p.id, sessionID: "upper-a", week: week, startedAt: at,
                                     finishedAt: at.addingTimeInterval(2_400), recovery: .fine, sets: sets)]
    }

    func floorToStep(_ kg: Double, _ p: Programme) -> Double {
        max(p.loadStepKg, (kg / p.loadStepKg + 1e-9).rounded(.down) * p.loadStepKg)
    }

    // MARK: - Bands

    @Test func bandsFollowTheAdvisor() {
        #expect(ReturnEasing(daysOff: 9, firstSessionDay: .now) == nil)
        #expect(ReturnEasing(daysOff: 10, firstSessionDay: .now)?.band == .short)
        #expect(ReturnEasing(daysOff: 20, firstSessionDay: .now)?.band == .short)
        #expect(ReturnEasing(daysOff: 21, firstSessionDay: .now)?.band == .long)
        #expect(ReturnEasing(daysOff: 41, firstSessionDay: .now)?.band == .long)
        #expect(ReturnEasing(daysOff: 42, firstSessionDay: .now)?.band == .restart)   // Advisor: 42 or more
        let short = ReturnEasing(daysOff: 12, firstSessionDay: .now)!
        #expect(short.line == "Easing back in after 12 days off")
        #expect([1, 2, 3].map(short.fraction(atSession:)) == [0.9, 1, 1])
        let long = ReturnEasing(daysOff: 30, firstSessionDay: .now)!
        #expect(abs(long.fraction(atSession: 2) - 0.9) < 1e-9)
        #expect([1, 3].map(long.fraction(atSession:)) == [0.8, 1])
        let restart = ReturnEasing(daysOff: 42, firstSessionDay: .now)!
        #expect([1, 2, 3, 4].map { Int((restart.fraction(atSession: $0) * 100).rounded()) } == [70, 80, 90, 100])
        #expect(long.todayLine(atSession: 1) == "Easing back in: 80% today")
        #expect(restart.todayLine(atSession: 3) == "Easing back in: 90% today")
    }

    @Test func aSoreSessionHoldsTheStep() throws {
        let p = try f.phase1()
        let before = try logged(weeks: 1, p)          // last strength day 5; day 35 is 30 days off
        let preKg = try #require(p.prescription(for: try bench(p), week: 6, history: before)?.kg)
        var history = try logUpperA(p, before, day: 35)
        history[history.count - 1].recovery = .sore   // came in sore: don't move on
        let held = try rx(p, history, day: 38)
        #expect(held.step == .easing)
        #expect(held.kg == floorToStep(preKg * 0.8, p))   // still 80%, not 90; never dropped back
        #expect(p.easingStep(history: history, on: f.day(38, hour: 7), calendar: f.calendar)?.session == 1)
        history = try logUpperA(p, history, day: 38)
        #expect(try rx(p, history, day: 42).kg == floorToStep(preKg * 0.9, p))
        let today = try #require(p.easingStep(history: history, on: f.day(42, hour: 7), calendar: f.calendar))
        #expect(today.easing.todayLine(atSession: today.session) == "Easing back in: 90% today")
    }

    // MARK: - 10–20 days

    @Test func twoWeeksOffEasesTo90ThenBackWithinTwoSessions() throws {
        let p = try f.phase1()
        let before = try logged(weeks: 2, p)          // last strength: Sat 28 Nov (day 12)
        let preBreak = try #require(p.prescription(for: try bench(p), week: 5, history: before))
        let preKg = try #require(preBreak.kg)

        // Mon 14 Dec (day 28): 16 days off.
        let first = try rx(p, before, day: 28)
        #expect(first.step == .easing)
        #expect(first.kg == floorToStep(preKg * 0.9, p))
        #expect(first.kg! < preKg)
        #expect(first.reps == preBreak.reps)
        #expect(first.repsInReserve == preBreak.repsInReserve)
        let script = try #require(WorkoutScript.make(sessionID: "upper-a", programme: p, week: 4, history: before,
                                                     on: f.day(28, hour: 7), calendar: f.calendar))
        #expect(script.easing?.line == "Easing back in after 16 days off")
        #expect(script.sets.first { $0.exercise == "dumbbell-bench-press" }?.kg == first.kg)

        // Logged at the eased weight; the next Upper A is back to the pre-break prescription.
        let after = try logUpperA(p, before, day: 28)
        let second = try rx(p, after, day: 35)
        #expect(second.step != .easing)
        #expect(second.kg == preKg)
        #expect(second.reps == preBreak.reps)           // the eased session didn't climb the reps
        #expect(WorkoutScript.make(sessionID: "upper-a", programme: p, week: 5, history: after,
                                   on: f.day(35, hour: 7), calendar: f.calendar)?.easing == nil)
    }

    // MARK: - 21–42 days

    @Test func fourWeeksOffEasesTo80WithAnExtraRepInReserveAndRebuildsOverThree() throws {
        let p = try f.phase1()
        let before = try logged(weeks: 1, p)          // last strength: Sat 21 Nov (day 5)
        let preBreak = try #require(p.prescription(for: try bench(p), week: 6, history: before))
        let preKg = try #require(preBreak.kg)

        // Mon 21 Dec (day 35): 30 days off.
        let first = try rx(p, before, day: 35)
        #expect(first.kg == floorToStep(preKg * 0.8, p))
        #expect(first.repsInReserve == preBreak.repsInReserve + 1)
        var history = try logUpperA(p, before, day: 35)

        // Thursday, still the first week back: 90%, still the extra rep in reserve.
        let second = try rx(p, history, day: 38)
        #expect(second.step == .easing)
        #expect(second.kg == floorToStep(preKg * 0.9, p))
        #expect(second.repsInReserve == preBreak.repsInReserve + 1)
        history = try logUpperA(p, history, day: 38)

        // The third session: back to the pre-break load, normal reserve.
        let third = try rx(p, history, day: 42)
        #expect(third.step != .easing)
        #expect(third.kg == preKg)
        #expect(third.repsInReserve == preBreak.repsInReserve)   // week 6 (held), no extra
    }

    // MARK: - Over 42 days

    @Test func overSixWeeksOffRestartsAtWeekOneEffortAnd70PercentAndTellsClaude() throws {
        let p = try f.phase1()
        let before = try logged(weeks: 1, p)          // last strength: day 5
        let preBreak = try #require(p.prescription(for: try bench(p), week: 6, history: before))
        let weekOne = try #require(p.prescription(for: try bench(p), week: 1, history: before))
        let day = 5 + 50                              // 50 days off
        let first = try rx(p, before, day: day)
        #expect(first.kg == floorToStep(try #require(preBreak.kg) * 0.7, p))
        #expect(first.sets == weekOne.sets)
        #expect(first.repsInReserve == weekOne.repsInReserve)

        let text = try #require(CoachSummary.text(programme: p, profile: f.profile(), history: before,
                                                  weights: f.losing(0.3, to: day), blocks: [],
                                                  now: f.day(day, hour: 7), calendar: f.calendar))
        #expect(text.contains("- Back after 50 days off: easing in at 70% of last loads, from week 1 effort, back to them by session 4"))
    }

    // MARK: - Normal weeks, and runs

    @Test func normalWeeksAreUnchanged() throws {
        let p = try f.phase1()
        let history = try loop.fourWeeks(p)
        for item in p.strengthItems {
            for day in [28, 31, 33] {
                let week = try #require(p.plannedDay(on: f.day(day), start: f.start, calendar: f.calendar).week)
                #expect(p.prescription(for: item, week: week, history: history, blocks: [], on: f.day(day, hour: 7),
                                       calendar: f.calendar)
                        == p.prescription(for: item, week: week, history: history), "\(item.exercise) day \(day)")
            }
        }
        #expect(p.easing(history: history, on: f.day(28, hour: 7), calendar: f.calendar) == nil)
        // A brand-new owner has no break to come back from.
        #expect(p.easing(history: [], on: f.day(28, hour: 7), calendar: f.calendar) == nil)
        // 9 days off is not a break.
        #expect(p.easing(history: try logged(weeks: 2, p), on: f.day(21, hour: 7), calendar: f.calendar) == nil)
    }

    @Test func runsKeepTheirOwnClock() throws {
        let p = try f.phase1()
        let history = try loop.fourWeeks(p)           // last run: Tue 8 Dec (day 22), week 4
        #expect(p.runWeek(5, history: history, on: f.day(29, hour: 7), calendar: f.calendar) == 5)  // 7 days
        #expect(p.runWeek(5, history: history, on: f.day(32, hour: 7), calendar: f.calendar) == 4)  // 10: repeat week 4
        #expect(p.runWeek(6, history: history, on: f.day(43, hour: 7), calendar: f.calendar) == 3)  // 21: one before
        #expect(p.runWeek(6, history: history, on: f.day(64, hour: 7), calendar: f.calendar) == 2)  // 42: two before
        #expect(p.runWeek(2, history: history, on: f.day(32, hour: 7), calendar: f.calendar) == 2)  // never past the plan
        let early = try logged(weeks: 1, p)           // last run week 1
        #expect(p.runWeek(6, history: early, on: f.day(60, hour: 7), calendar: f.calendar) == 1)    // never before week 1
        #expect(p.runWeek(2, history: [], on: f.day(8, hour: 7), calendar: f.calendar) == 2)
        // Separate clocks: runs kept going, lifts stopped. Lifts ease, runs don't.
        let runsOnly = early + [SessionLog(programmeID: p.id, sessionID: "run-1", week: 4, startedAt: f.day(22, hour: 7),
                                           finishedAt: f.day(22, hour: 8))]
        #expect(p.runWeek(5, history: runsOnly, on: f.day(29, hour: 7), calendar: f.calendar) == 5)
        #expect(p.easing(history: runsOnly, on: f.day(28, hour: 7), calendar: f.calendar) != nil)
    }
}
