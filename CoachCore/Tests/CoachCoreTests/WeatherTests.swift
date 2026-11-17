import Foundation
import Testing
@testable import CoachCore

/// Board M2-03: a bad forecast swaps an outdoor run for the indoor session of
/// the same length without moving the wake time; offline means no swap, no error.
@Suite struct WeatherTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    /// Week 1 starts Monday 23 Nov 2026; run-1 is on Tuesdays, run-2 on Sundays from week 4.
    private func day(_ weekday: Weekday, week: Int = 1) throws -> WeekPlan.Day {
        var profile = Profile()
        profile.confirmed = true
        profile.programme.startDate = date(2026, 11, 23)
        let monday = calendar.date(byAdding: .day, value: 7 * (week - 1), to: date(2026, 11, 23))!
        let plan = WeekPlanner.plan(weekStarting: monday, programme: try phase1(), profile: profile,
                                    answers: WeekAnswers(), dropping: [], calendar: calendar)
        return try #require(plan.day(weekday))
    }

    /// 24 hours of dry, mild weather on `day`, with `edit` changing any hour.
    private func forecast(on day: Date, _ edit: (Int) -> ForecastHour? = { _ in nil }) -> Forecast {
        Forecast(hours: (0..<24).map { h in
            let start = calendar.date(byAdding: .hour, value: h, to: calendar.startOfDay(for: day))!
            return edit(h).map { e in
                ForecastHour(start: start, precipitationMm: e.precipitationMm,
                             precipitationProbability: e.precipitationProbability, temperatureC: e.temperatureC,
                             windGustKmh: e.windGustKmh, weatherCode: e.weatherCode)
            } ?? ForecastHour(start: start)
        })
    }

    private let anyStart = Date(timeIntervalSince1970: 0)

    private func rain(_ mm: Double, chance: Int = 90) -> ForecastHour {
        ForecastHour(start: anyStart, precipitationMm: mm, precipitationProbability: chance, weatherCode: 63)
    }

    private func decide(_ day: WeekPlan.Day, _ forecast: Forecast?, runAnyway: Bool = false) throws -> WeatherDecision {
        WeatherSwap.decide(day: day, programme: try phase1(), forecast: forecast, runAnyway: runAnyway, calendar: calendar)
    }

    // MARK: The swap

    @Test func rainDuringTheRunSwapsToTheIndoorCircuitAtTheSameTime() throws {
        let tuesday = try day(.tuesday)
        let placement = try #require(tuesday.session)
        #expect(placement.sessionID == "run-1")
        let wet = forecast(on: tuesday.date) { $0 == placement.start.hour ? rain(2.5) : nil }

        let swap = try #require(try decide(tuesday, wet).swap)
        #expect(swap.from == "run-1")
        #expect(swap.to == "indoor-circuit")
        #expect(swap.rounds == 4)
        #expect(swap.durationMinutes == 28) // run-1 week 1 is 28 minutes
        #expect(swap.start == placement.start)
        #expect(swap.end == placement.end)
        #expect(swap.reason == .rain)
        #expect(swap.note(programme: try phase1()) == "Rain forecast: indoor circuit instead, same time")
        // Nothing in the plan moves, so the alarm (and its id) stays as reconciled.
        #expect(try day(.tuesday) == tuesday)
    }

    @Test func weekFourSundayRunSwapsToThreeRounds() throws {
        let sunday = try day(.sunday, week: 4)
        let placement = try #require(sunday.session)
        #expect(placement.sessionID == "run-2")
        let wet = forecast(on: sunday.date) { $0 == placement.start.hour ? rain(4) : nil }
        let swap = try #require(try decide(sunday, wet).swap)
        #expect(swap.rounds == 3)
        #expect(swap.durationMinutes == 20)
    }

    @Test func everyIndoorSwapFitsInsideItsRun() throws {
        for (id, session) in try phase1().sessions {
            guard case let .runWalk(run) = session else { continue }
            for week in run.weeks {
                let swap = try #require(week.indoorSwap, "\(id) week \(week.week) has no indoor swap")
                #expect(swap.durationMinutes <= week.durationMinutes, "\(id) week \(week.week)")
            }
        }
    }

    // MARK: When nothing changes

    @Test func drizzleIsNotBadWeather() throws {
        let tuesday = try day(.tuesday)
        let hour = try #require(tuesday.session).start.hour
        let damp = forecast(on: tuesday.date) { $0 == hour ? rain(0.4) : nil }
        #expect(try decide(tuesday, damp) == .keep(.fine))
    }

    @Test func unlikelyRainIsNotBadWeather() throws {
        let tuesday = try day(.tuesday)
        let hour = try #require(tuesday.session).start.hour
        let maybe = forecast(on: tuesday.date) { $0 == hour ? rain(3, chance: 30) : nil }
        #expect(try decide(tuesday, maybe) == .keep(.fine))
    }

    @Test func rainOutsideTheSessionHoursChangesNothing() throws {
        let tuesday = try day(.tuesday)
        let wetAfternoon = forecast(on: tuesday.date) { (13...18).contains($0) ? rain(5) : nil }
        #expect(try decide(tuesday, wetAfternoon) == .keep(.fine))
    }

    @Test func offlineMeansNoSwapAndNoError() throws {
        let tuesday = try day(.tuesday)
        #expect(try decide(tuesday, nil) == .keep(.noForecast))
        // A stale forecast for another day says nothing about this one.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: tuesday.date)!
        #expect(try decide(tuesday, forecast(on: yesterday) { _ in rain(9) }) == .keep(.noForecast))
    }

    @Test func runAnywayKeepsTheRun() throws {
        let tuesday = try day(.tuesday)
        let wet = forecast(on: tuesday.date) { _ in rain(3) }
        #expect(try decide(tuesday, wet, runAnyway: true) == .keep(.runAnyway))
    }

    @Test func indoorSessionsAreNeverSwapped() throws {
        let monday = try day(.monday)
        #expect(monday.session?.sessionID == "upper-a")
        #expect(try decide(monday, forecast(on: monday.date) { _ in rain(9) }) == .keep(.notOutdoor))
        let friday = try day(.friday) // no session
        #expect(try decide(friday, nil) == .keep(.notOutdoor))
    }

    // MARK: The rule

    @Test func worstWeatherNamesTheSwap() {
        let start = date(2026, 11, 24, 8)
        let end = start.addingTimeInterval(30 * 60)
        func verdict(_ hour: ForecastHour) -> BadWeather? {
            WeatherRule.badWeather(in: Forecast(hours: [hour]), from: start, to: end)
        }
        #expect(verdict(ForecastHour(start: start)) == nil)
        #expect(verdict(ForecastHour(start: start, precipitationMm: 3, precipitationProbability: 90, weatherCode: 95)) == .thunder)
        #expect(verdict(ForecastHour(start: start, weatherCode: 71)) == .snowOrIce)
        #expect(verdict(ForecastHour(start: start, windGustKmh: 65)) == .wind)
        #expect(verdict(ForecastHour(start: start, windGustKmh: 55)) == nil)
        #expect(verdict(ForecastHour(start: start, temperatureC: -4)) == .cold)
        #expect(verdict(ForecastHour(start: start, temperatureC: -1)) == nil)
        // Missing values are no evidence either way; a missing chance trusts the amount.
        #expect(verdict(ForecastHour(start: start, precipitationMm: nil, precipitationProbability: nil,
                                     temperatureC: nil, windGustKmh: nil, weatherCode: nil)) == nil)
        #expect(verdict(ForecastHour(start: start, precipitationMm: 2, precipitationProbability: nil)) == .rain)
    }

    @Test func anHourThatStartsBeforeTheSessionStillCounts() {
        // 07:00–08:00 rain overlaps a 07:40 start.
        let rainy = ForecastHour(start: date(2026, 11, 24, 7), precipitationMm: 2, precipitationProbability: 80)
        let start = date(2026, 11, 24, 7).addingTimeInterval(40 * 60)
        #expect(WeatherRule.badWeather(in: Forecast(hours: [rainy]), from: start, to: start.addingTimeInterval(1800)) == .rain)
        // An hour that ends as the session starts does not.
        let earlier = ForecastHour(start: date(2026, 11, 24, 6), precipitationMm: 2, precipitationProbability: 80)
        let eight = date(2026, 11, 24, 7)
        #expect(WeatherRule.badWeather(in: Forecast(hours: [earlier]), from: eight, to: eight.addingTimeInterval(1800)) == nil)
    }

    // MARK: Open-Meteo

    @Test func requestSendsOnlyThePublicRouteAndNoKey() throws {
        let park = try #require(RouteLocation.known["hyde-park"])
        let url = OpenMeteo.forecastURL(latitude: park.latitude, longitude: park.longitude)
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(parts.scheme == "https")
        #expect(parts.host == "api.open-meteo.com")
        let names = Set((parts.queryItems ?? []).map(\.name))
        #expect(names == ["latitude", "longitude", "hourly", "wind_speed_unit", "timeformat", "timezone", "forecast_days"])
        #expect(parts.queryItems?.first { $0.name == "latitude" }?.value == "51.5073")
    }

    @Test func decodesHourlyDataWithNulls() throws {
        let json = #"""
        {"latitude":51.5,"longitude":-0.16,"hourly_units":{"time":"unixtime"},
         "hourly":{"time":[1795593600,1795597200],
                   "precipitation":[0.0,2.4],
                   "precipitation_probability":[5,null],
                   "temperature_2m":[7.1,6.8],
                   "wind_gusts_10m":[20.5,31.0],
                   "weather_code":[3,63]}}
        """#
        let forecast = try OpenMeteo.decode(Data(json.utf8))
        #expect(forecast.hours.count == 2)
        #expect(forecast.hours[0].start == Date(timeIntervalSince1970: 1_795_593_600))
        #expect(forecast.hours[1].precipitationMm == 2.4)
        #expect(forecast.hours[1].precipitationProbability == nil)
        #expect(forecast.hours[1].weatherCode == 63)
    }

    @Test func badResponsesThrowRatherThanGuess() {
        let uneven = #"{"hourly":{"time":[1,2],"precipitation":[0.0]}}"#
        #expect(throws: OpenMeteo.DecodeError.mismatchedLengths) { try OpenMeteo.decode(Data(uneven.utf8)) }
        #expect(throws: (any Error).self) { try OpenMeteo.decode(Data("not json".utf8)) }
    }
}
