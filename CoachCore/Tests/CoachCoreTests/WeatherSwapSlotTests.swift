import Foundation
import Testing
@testable import CoachCore

/// Today shows and starts the indoor session when the morning's forecast swaps the run (M2-03, M2-05).
@Suite struct WeatherSwapSlotTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    /// Tuesday 24 Nov 2026, week 1: the run-walk.
    private func tuesdayRun(_ programme: Programme) throws -> DayPlan.SessionSlot {
        var profile = Profile()
        profile.confirmed = true
        profile.programme.startDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23))!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 7))!
        let plan = try #require(DayPlan.make(for: tuesday, programme: programme, profile: profile, calendar: calendar))
        return try #require(plan.session)
    }

    private func swap(from: String, to: String = "indoor-circuit", start: TimeOfDay) -> WeatherSwap {
        WeatherSwap(from: from, to: to, rounds: 3, coolDownMinutes: 5, durationMinutes: 28,
                    start: start, end: start.adding(minutes: 28), reason: .rain)
    }

    @Test func swapKeepsTheStartAndTakesTheIndoorSession() throws {
        let programme = try phase1()
        let run = try tuesdayRun(programme)
        let indoor = try #require(run.swapped(by: swap(from: run.id, start: run.start), programme: programme))
        #expect(indoor.id == "indoor-circuit")
        #expect(indoor.name == programme.sessions["indoor-circuit"]?.name)
        #expect(indoor.start == run.start)
        #expect(indoor.minutes == 28)
    }

    @Test func aSwapForAnotherSessionChangesNothing() throws {
        let programme = try phase1()
        let run = try tuesdayRun(programme)
        #expect(run.swapped(by: swap(from: "upper-a", start: run.start), programme: programme) == nil)
        #expect(run.swapped(by: swap(from: run.id, to: "no-such-session", start: run.start), programme: programme) == nil)
    }
}
