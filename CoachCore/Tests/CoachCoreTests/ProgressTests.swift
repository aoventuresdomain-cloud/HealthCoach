import Foundation
import Testing
@testable import CoachCore

/// Board M4-03: photos every 2 weeks and strength by lift.
@Suite struct ProgressTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    /// Paper start, decision E13.
    private var start: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 16))! }

    // MARK: Photos

    @Test func photoDayEveryTwoWeeksFromTheStart() {
        #expect(PhotoSchedule.blockStart(for: date(2026, 11, 16), start: start, calendar: calendar) == date(2026, 11, 16, 0))
        #expect(PhotoSchedule.blockStart(for: date(2026, 11, 29), start: start, calendar: calendar) == date(2026, 11, 16, 0))
        #expect(PhotoSchedule.blockStart(for: date(2026, 11, 30), start: start, calendar: calendar) == date(2026, 11, 30, 0))
        #expect(PhotoSchedule.blockStart(for: date(2026, 11, 15), start: start, calendar: calendar) == nil)
        #expect(PhotoSchedule.nextPhotoDay(after: date(2026, 11, 20), start: start, calendar: calendar) == date(2026, 11, 30, 0))
        #expect(PhotoSchedule.dayKey(date(2026, 11, 23, 23), calendar: calendar) == "2026-11-23")
    }

    @Test func dueUntilTakenInTheBlockAndNeverCarriedOver() {
        #expect(PhotoSchedule.isDue(on: date(2026, 11, 17), start: start, taken: [], calendar: calendar))
        #expect(!PhotoSchedule.isDue(on: date(2026, 11, 17), start: start, taken: [date(2026, 11, 16)], calendar: calendar))
        #expect(!PhotoSchedule.isDue(on: date(2026, 11, 28), start: start, taken: [date(2026, 11, 16)], calendar: calendar))
        // Next block: due again, one set only, however many blocks were missed.
        #expect(PhotoSchedule.isDue(on: date(2026, 11, 30), start: start, taken: [date(2026, 11, 16)], calendar: calendar))
        #expect(PhotoSchedule.isDue(on: date(2026, 12, 28), start: start, taken: [date(2026, 11, 16)], calendar: calendar))
        #expect(!PhotoSchedule.isDue(on: date(2026, 11, 17), start: nil, taken: [], calendar: calendar))
    }

    @Test func photoBlocksSurviveTheClockChange() {
        // Blocks of 14 calendar days across the last Sunday of March 2027.
        let spring = calendar.date(from: DateComponents(year: 2027, month: 3, day: 22))!
        #expect(PhotoSchedule.blockStart(for: date(2027, 4, 5), start: spring, calendar: calendar) == date(2027, 4, 5, 0))
        #expect(PhotoSchedule.blockStart(for: date(2027, 4, 4, 23), start: spring, calendar: calendar) == date(2027, 3, 22, 0))
    }

    // MARK: Strength

    private func log(_ day: Int, _ sets: [SetLog]) -> SessionLog {
        var l = SessionLog(programmeID: "phase-1", sessionID: "upper-a", week: 1, startedAt: date(2026, 11, day))
        l.sets = sets
        return l
    }

    @Test func bestSetPerSessionPerLiftOldestFirst() throws {
        let history = [
            log(30, [SetLog(exercise: "bench", setIndex: 0, reps: 9, kg: 10, asPrescribed: true),
                     SetLog(exercise: "bench", setIndex: 1, reps: 7, kg: 12, asPrescribed: false)]),
            log(23, [SetLog(exercise: "bench", setIndex: 0, reps: 8, kg: 10, asPrescribed: true),
                     SetLog(exercise: "bench", setIndex: 1, reps: 8, kg: 10, asPrescribed: true),
                     SetLog(exercise: "plank", setIndex: 0, seconds: 30, asPrescribed: true)]),
        ]
        let lifts = StrengthProgress.lifts(from: history)
        #expect(lifts.map(\.exercise) == ["bench", "plank"])
        let bench = try #require(lifts.first)
        #expect(bench.points.map(\.kg) == [10, 12])
        #expect(bench.points.map(\.reps) == [8, 7])
        #expect(StrengthProgress.change(bench) == "10 kg × 8 → 12 kg × 7")
        #expect(StrengthProgress.change(try #require(lifts.last)) == "30 s")
        #expect(StrengthProgress.loadWentUp(bench))
        #expect(!StrengthProgress.loadWentUp(try #require(lifts.last)))
    }

    @Test func noHistoryNoLifts() {
        #expect(StrengthProgress.lifts(from: []).isEmpty)
    }
}

@Suite struct WeightChartTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 7))!
    }

    @Test func oneAveragePerDayWithAFullEnoughWindow() throws {
        // Daily weigh-ins 10–23 Nov, 82.0 falling 0.1 a day.
        let samples = (10...23).map { WeightSample(date: day($0), kg: 82.0 - Double($0 - 10) * 0.1) }
        let points = WeightChart.averages(samples: samples, endingOn: day(23), calendar: calendar)
        #expect(points.count == 8)
        #expect(points.map(\.averageKg) == points.map(\.averageKg).sorted(by: >))
        let last = try #require(points.last)
        #expect(abs(last.averageKg - (82.0 - 1.0)) < 0.001)
    }

    @Test func noWeighInsNoLine() {
        #expect(WeightChart.averages(samples: [], endingOn: day(23), calendar: calendar).isEmpty)
    }

    @Test func phaseLineCountsFromTheStart() throws {
        let programme = try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16))!
        let lines = try #require(PhaseLine.lines(programme: programme, start: start, on: day(30), calendar: calendar))
        #expect(lines.phase == "Phase \(programme.phase) · week 3 of \(programme.weeks)")
        #expect(lines.overall == "Week 3 of about 20")
        #expect(PhaseLine.lines(programme: programme, start: nil, on: day(30), calendar: calendar) == nil)
    }
}
