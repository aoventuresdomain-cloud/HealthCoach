import Foundation

// Board M2-03: when the morning brief opens, a bad forecast for an outdoor
// run swaps it for the indoor session of the same length, so the wake time
// never moves (plan §4.1, Advisor response #15). "I'll run anyway" is one tap.
// No forecast (offline, a failed fetch) means no swap and no error.

/// One hour of forecast, starting at `start`.
public struct ForecastHour: Sendable, Equatable {
    public let start: Date
    /// Rain, showers and snow (as water) expected in the hour.
    public let precipitationMm: Double?
    /// Chance of at least 0.1 mm in the hour, 0–100.
    public let precipitationProbability: Int?
    public let temperatureC: Double?
    public let windGustKmh: Double?
    /// WMO weather interpretation code.
    public let weatherCode: Int?

    public init(start: Date, precipitationMm: Double? = 0, precipitationProbability: Int? = 0,
                temperatureC: Double? = 10, windGustKmh: Double? = 10, weatherCode: Int? = 0) {
        self.start = start
        self.precipitationMm = precipitationMm
        self.precipitationProbability = precipitationProbability
        self.temperatureC = temperatureC
        self.windGustKmh = windGustKmh
        self.weatherCode = weatherCode
    }
}

public struct Forecast: Sendable, Equatable {
    public let hours: [ForecastHour]
    public init(hours: [ForecastHour]) { self.hours = hours.sorted { $0.start < $1.start } }
}

/// Open-Meteo's free forecast API: no key, no account (plan §5, £0). The only
/// thing sent is the route's public coordinates, never the owner's location
/// or any health data.
public enum OpenMeteo {
    public static func forecastURL(latitude: Double, longitude: Double) -> URL {
        var parts = URLComponents()
        parts.scheme = "https"
        parts.host = "api.open-meteo.com"
        parts.path = "/v1/forecast"
        parts.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "precipitation,precipitation_probability,temperature_2m,wind_gusts_10m,weather_code"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "GMT"),
            URLQueryItem(name: "forecast_days", value: "2"),
        ]
        return parts.url!
    }

    public enum DecodeError: Error, Equatable {
        /// The hourly arrays have different lengths.
        case mismatchedLengths
    }

    /// Parses the `hourly` block of a forecast response. Missing values
    /// (`null`) stay nil and count as no evidence of bad weather.
    public static func decode(_ data: Data) throws -> Forecast {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let h = response.hourly
        let n = h.time.count
        for count in [h.precipitation?.count, h.probability?.count, h.temperature?.count,
                      h.gusts?.count, h.code?.count] {
            if let count, count != n { throw DecodeError.mismatchedLengths }
        }
        let hours = (0..<n).map { i in
            ForecastHour(
                start: Date(timeIntervalSince1970: h.time[i]),
                precipitationMm: h.precipitation?[i],
                precipitationProbability: h.probability?[i].map { Int($0.rounded()) },
                temperatureC: h.temperature?[i],
                windGustKmh: h.gusts?[i],
                weatherCode: h.code?[i].map { Int($0) })
        }
        return Forecast(hours: hours)
    }

    private struct Response: Decodable {
        let hourly: Hourly
    }

    private struct Hourly: Decodable {
        let time: [Double]
        let precipitation: [Double?]?
        let probability: [Double?]?
        let temperature: [Double?]?
        let gusts: [Double?]?
        let code: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time, precipitation
            case probability = "precipitation_probability"
            case temperature = "temperature_2m"
            case gusts = "wind_gusts_10m"
            case code = "weather_code"
        }
    }
}

/// Where the forecast is taken for each route in the programme data. Public
/// places only; the app never asks for or sends the owner's location.
public struct RouteLocation: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public static let known: [String: RouteLocation] = [
        "hyde-park": RouteLocation(latitude: 51.5073, longitude: -0.1657),
    ]
}

/// Why a run counts as rained off.
public enum BadWeather: String, Sendable, Equatable {
    case rain, thunder, snowOrIce, wind, cold

    /// For the one-line note on Today.
    public var phrase: String {
        switch self {
        case .rain: "Rain forecast"
        case .thunder: "Thunderstorms forecast"
        case .snowOrIce: "Snow or ice forecast"
        case .wind: "Strong wind forecast"
        case .cold: "Icy cold forecast"
        }
    }
}

/// The thresholds for "bad weather" during a run (docs/weather.md). Light
/// drizzle is not bad weather: a London run would be swapped most weeks.
public enum WeatherRule {
    /// Rain counts when an hour expects at least this much...
    public static let rainMm = 1.0
    /// ...and the chance of rain is at least this (when given).
    public static let rainProbability = 50
    public static let gustKmh = 60.0
    /// Below this, paths in the park may be icy.
    public static let coldC = -3.0
    static let thunderCodes: Set<Int> = [95, 96, 99]
    /// Freezing drizzle and rain, snow, snow grains and snow showers.
    static let snowOrIceCodes: Set<Int> = [56, 57, 66, 67, 71, 73, 75, 77, 85, 86]

    /// The worst problem in the hours that overlap `start..<end`, or nil when
    /// they all look fine. Returns nil too when no hour covers the window: no
    /// forecast is never a reason to swap.
    public static func badWeather(in forecast: Forecast, from start: Date, to end: Date) -> BadWeather? {
        let hours = forecast.hours.filter { $0.start < end && $0.start.addingTimeInterval(3600) > start }
        var found: [BadWeather] = []
        for hour in hours {
            if let code = hour.weatherCode, thunderCodes.contains(code) { found.append(.thunder) }
            if let code = hour.weatherCode, snowOrIceCodes.contains(code) { found.append(.snowOrIce) }
            if let mm = hour.precipitationMm, mm >= rainMm, (hour.precipitationProbability ?? 100) >= rainProbability {
                found.append(.rain)
            }
            if let gust = hour.windGustKmh, gust >= gustKmh { found.append(.wind) }
            if let temp = hour.temperatureC, temp <= coldC { found.append(.cold) }
        }
        // Most serious first, for the note.
        let order: [BadWeather] = [.thunder, .snowOrIce, .wind, .rain, .cold]
        return order.first { found.contains($0) }
    }

    /// True when the forecast has an hour that covers the window at all.
    public static func covers(_ forecast: Forecast, from start: Date, to end: Date) -> Bool {
        forecast.hours.contains { $0.start < end && $0.start.addingTimeInterval(3600) > start }
    }
}

/// What the morning brief does with today's session.
public enum WeatherDecision: Sendable, Equatable {
    case keep(Keep)
    case swap(WeatherSwap)

    public enum Keep: String, Sendable, Equatable {
        /// No session today, or it isn't an outdoor one.
        case notOutdoor
        /// The forecast for the session's hours looks fine.
        case fine
        /// No forecast covers the session (offline, failed fetch): no swap, no error.
        case noForecast
        /// Bad weather, but the owner tapped "I'll run anyway".
        case runAnyway
        /// Bad weather, but the programme has no indoor session for this week.
        case noIndoorSession
    }

    public var swap: WeatherSwap? {
        switch self {
        case let .swap(s): s
        case .keep: nil
        }
    }
}

/// An outdoor run replaced by its indoor session. The placement (and so the
/// wake time and the alarm) stays exactly as planned.
public struct WeatherSwap: Sendable, Equatable {
    public let from: String
    /// Key into `Programme.sessions`.
    public let to: String
    public let rounds: Int
    public let coolDownMinutes: Int
    public let durationMinutes: Int
    public let start: TimeOfDay
    public let end: TimeOfDay
    public let reason: BadWeather

    /// "Rain forecast: indoor circuit instead, same time".
    public func note(programme: Programme) -> String {
        let name = programme.sessions[to]?.name.lowercased() ?? to
        return "\(reason.phrase): \(name) instead, same time"
    }
}

extension WeatherSwap {
    /// Decides today's session. `forecast` nil means none could be fetched.
    public static func decide(day: WeekPlan.Day, programme: Programme, forecast: Forecast?,
                              runAnyway: Bool, calendar: Calendar) -> WeatherDecision {
        guard let placement = day.session, let week = day.week,
              programme.placementRules.outdoorSessions.contains(placement.sessionID),
              case let .runWalk(run)? = programme.sessions[placement.sessionID] else {
            return .keep(.notOutdoor)
        }
        guard let forecast,
              let start = calendar.date(bySettingHour: placement.start.hour, minute: placement.start.minute,
                                        second: 0, of: day.date),
              let end = calendar.date(bySettingHour: placement.end.hour, minute: placement.end.minute,
                                      second: 0, of: day.date),
              WeatherRule.covers(forecast, from: start, to: end) else {
            return .keep(.noForecast)
        }
        guard let reason = WeatherRule.badWeather(in: forecast, from: start, to: end) else {
            return .keep(.fine)
        }
        if runAnyway { return .keep(.runAnyway) }
        // Only a session that fits the run's slot keeps the wake time.
        guard let runWeek = run.weeks.first(where: { $0.week == week }),
              let indoor = runWeek.indoorSwap,
              indoor.durationMinutes <= runWeek.durationMinutes,
              programme.sessions[indoor.session] != nil else {
            return .keep(.noIndoorSession)
        }
        return .swap(WeatherSwap(
            from: placement.sessionID, to: indoor.session, rounds: indoor.rounds,
            coolDownMinutes: indoor.coolDownMinutes, durationMinutes: indoor.durationMinutes,
            start: placement.start, end: placement.end, reason: reason))
    }
}
