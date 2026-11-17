import CoachCore
import Foundation
import Observation

/// Fetches a forecast for a public route location. The app's only network call.
protocol ForecastFetching: Sendable {
    func forecast(at location: RouteLocation) async throws -> Forecast
}

/// Open-Meteo over HTTPS: no key, no account, nothing about the owner sent.
/// Ephemeral session, so no cookies or cache are kept on disk.
nonisolated struct OpenMeteoClient: ForecastFetching {
    static let timeoutSeconds: TimeInterval = 8

    func forecast(at location: RouteLocation) async throws -> Forecast {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Self.timeoutSeconds
        configuration.timeoutIntervalForResource = Self.timeoutSeconds
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let url = OpenMeteo.forecastURL(latitude: location.latitude, longitude: location.longitude)
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try OpenMeteo.decode(data)
    }
}

/// UI tests (`-weather rain|dry|offline`): a fixed 48-hour forecast from the
/// start of `day`, or no network at all.
nonisolated struct FakeForecast: ForecastFetching {
    enum Kind: String { case rain, dry, offline }
    let kind: Kind
    let day: Date

    func forecast(at location: RouteLocation) async throws -> Forecast {
        if kind == .offline { throw URLError(.notConnectedToInternet) }
        let start = Calendar.current.startOfDay(for: day)
        return Forecast(hours: (0..<48).map { h in
            ForecastHour(start: start.addingTimeInterval(Double(h) * 3600),
                         precipitationMm: kind == .rain ? 3 : 0,
                         precipitationProbability: kind == .rain ? 90 : 5,
                         weatherCode: kind == .rain ? 63 : 1)
        })
    }
}

/// Board M2-03: on a day with an outdoor run, opening the app checks the
/// forecast. Bad weather swaps the run for its indoor session in the same
/// slot, so the wake time and alarm never move. "I'll run anyway" is one tap
/// and lasts for the day. No forecast means no swap and no error.
///
/// Today reads `decision` (the swap note and the run-anyway button); nothing
/// else in the plan changes.
@MainActor
@Observable
final class MorningWeather {
    static let shared = MorningWeather()

    /// Today's answer; nil before the first check.
    private(set) var decision: WeatherDecision?
    /// Today's planned day, for the note's session times.
    private(set) var today: WeekPlan.Day?

    /// Re-fetch at most this often while the app is reopened through the morning.
    static let refreshSeconds: TimeInterval = 30 * 60

    @ObservationIgnored private let fetcher: any ForecastFetching
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var forecast: Forecast?
    @ObservationIgnored private var fetchedAt: Date?
    @ObservationIgnored private var programme: Programme?
    private static let runAnywayKey = "weather.runAnyway.v1"

    init(fetcher: (any ForecastFetching)? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let fetcher {
            self.fetcher = fetcher
        } else if LaunchOptions.current.isUITest {
            // UI tests never touch the network: no flag means offline.
            let kind = LaunchOptions.current.weather.flatMap(FakeForecast.Kind.init(rawValue:)) ?? .offline
            self.fetcher = FakeForecast(kind: kind, day: AppClock.now())
        } else {
            self.fetcher = OpenMeteoClient()
        }
    }

    /// Checks today's session against the forecast. Only fetches on a day with
    /// an outdoor session that hasn't finished yet.
    @discardableResult
    func check(profile: Profile, now: Date = AppClock.now(), answers: WeekAnswersStore = WeekAnswersStore(),
               calendar: Calendar = .current) async -> WeatherDecision {
        guard let content = try? BundledContent.load(),
              let programme = content.programmes[profile.programme.programmeID],
              profile.programme.startDate != nil else {
            return settle(.keep(.notOutdoor), day: nil)
        }
        self.programme = programme
        let monday = AlarmSchedule.mondayOf(now, calendar: calendar)
        let plan = WeekPlanner.plan(weekStarting: monday, programme: programme, profile: profile,
                                    answers: answers.answers(weekStarting: monday, calendar: calendar),
                                    dropping: [], now: now, calendar: calendar)
        guard let day = plan.days.first(where: { calendar.isDate($0.date, inSameDayAs: now) }) else {
            return settle(.keep(.notOutdoor), day: nil)
        }
        // No network on a day without an outdoor run.
        let probe = WeatherSwap.decide(day: day, programme: programme, forecast: nil, runAnyway: false, calendar: calendar)
        if probe == .keep(.notOutdoor) { return settle(probe, day: day) }
        if let end = day.session.flatMap({ calendar.date(bySettingHour: $0.end.hour, minute: $0.end.minute, second: 0, of: day.date) }),
           now >= end {
            return settle(decision ?? .keep(.noForecast), day: day)
        }

        if fetchedAt.map({ now.timeIntervalSince($0) >= Self.refreshSeconds || !calendar.isDate($0, inSameDayAs: now) }) ?? true,
           let location = route(for: day, in: programme) {
            if let fresh = try? await fetcher.forecast(at: location) {
                forecast = fresh
                fetchedAt = now
            }
            // A failed fetch keeps any earlier forecast; with none, no swap.
        }
        let result = WeatherSwap.decide(day: day, programme: programme, forecast: forecast,
                                        runAnyway: ranAnyway(on: day.date, calendar: calendar), calendar: calendar)
        return settle(result, day: day)
    }

    /// "I'll run anyway": keeps today's run, for today only.
    func runAnyway(calendar: Calendar = .current) {
        guard let day = today, let programme else { return }
        defaults.set(Self.key(day.date, calendar: calendar), forKey: Self.runAnywayKey)
        settle(WeatherSwap.decide(day: day, programme: programme, forecast: forecast, runAnyway: true, calendar: calendar),
               day: day)
    }

    // MARK: - Private

    @discardableResult
    private func settle(_ result: WeatherDecision, day: WeekPlan.Day?) -> WeatherDecision {
        decision = result
        today = day
        return result
    }

    private func route(for day: WeekPlan.Day, in programme: Programme) -> RouteLocation? {
        guard let id = day.session?.sessionID, case let .runWalk(run)? = programme.sessions[id] else { return nil }
        return RouteLocation.known[run.route]
    }

    private func ranAnyway(on date: Date, calendar: Calendar) -> Bool {
        defaults.string(forKey: Self.runAnywayKey) == Self.key(date, calendar: calendar)
    }

    private static func key(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
