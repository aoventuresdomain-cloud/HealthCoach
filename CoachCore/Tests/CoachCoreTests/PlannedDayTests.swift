import Foundation
import Testing
@testable import CoachCore

@Suite struct PlannedDayTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 7) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    /// Monday 23 Nov 2026 is week 1 day 1.
    private var start: Date { date(2026, 11, 23, hour: 0) }

    @Test func weekOneMondayIsUpperA() throws {
        let day = try phase1().plannedDay(on: date(2026, 11, 23), start: start, calendar: calendar)
        #expect(day.week == 1)
        #expect(day.weekday == .monday)
        guard case let .session(id, _) = day.entry else { Issue.record("\(day.entry)"); return }
        #expect(id == "upper-a")
    }

    @Test func wednesdayIsBasketball() throws {
        let day = try phase1().plannedDay(on: date(2026, 11, 25), start: start, calendar: calendar)
        guard case let .fixed(event) = day.entry else { Issue.record("\(day.entry)"); return }
        #expect(event.id == "basketball")
    }

    @Test func fridayIsRest() throws {
        #expect(try phase1().plannedDay(on: date(2026, 11, 27), start: start, calendar: calendar).entry == .rest)
    }

    @Test func weekFourSundayIsTheSecondRun() throws {
        let day = try phase1().plannedDay(on: date(2026, 12, 20), start: start, calendar: calendar)
        #expect(day.week == 4)
        guard case let .session(id, _) = day.entry else { Issue.record("\(day.entry)"); return }
        #expect(id == "run-2")
    }

    @Test func beforeStartAndAfterEnd() throws {
        let programme = try phase1()
        #expect(programme.plannedDay(on: date(2026, 11, 22), start: start, calendar: calendar).entry == .beforeStart)
        // E13: past week 6, hold at week 6 (flagged for the team) until Phase 2 exists.
        let past = programme.plannedDay(on: date(2027, 1, 4), start: start, calendar: calendar)
        #expect(past.week == 6)
        #expect(past.heldAtLastWeek)
        #expect(past.entry != .afterEnd)
        #expect(programme.plannedDay(on: date(2027, 1, 3), start: start, calendar: calendar).week == 6)
    }

    @Test func lateEveningStaysOnTheSameDay() throws {
        let day = try phase1().plannedDay(on: date(2026, 11, 23, hour: 23), start: start, calendar: calendar)
        #expect(day.weekday == .monday && day.week == 1)
    }
}

@Suite struct SessionLogTests {
    @Test func roundTrips() throws {
        let log = SessionLog(programmeID: "phase-1", sessionID: "upper-a", week: 1,
                             startedAt: Date(timeIntervalSince1970: 1_795_000_000),
                             finishedAt: Date(timeIntervalSince1970: 1_795_002_400),
                             recovery: .fine,
                             sets: [SetLog(exercise: "dumbbell-bench-press", setIndex: 0, reps: 12, kg: 10, asPrescribed: true)])
        let encoder = JSONEncoder()
        let decoded = try JSONDecoder().decode(SessionLog.self, from: encoder.encode(log))
        #expect(decoded == log)
        #expect(decoded.isComplete)
    }
}
