import Foundation
import Testing
@testable import CoachCore

/// QA-R4 hygiene (privacy): the app talks to the network in exactly two
/// places, and neither carries anything about the owner (plan §4.7: health
/// data goes only to the owner's iCloud backup and the summaries they share).
///
/// - `App/Planner/MorningWeather.swift`: Open-Meteo's forecast for the fixed
///   public route coordinates (M2-03, no key, no account).
/// - `App/Meals/MealsHubView.swift`: the shop's search link, opened in Safari
///   by the owner's own tap (N4).
///
/// Reminders (N5) is EventKit on the device, and exercise GIFs come from the
/// app bundle (s4-gifs), so neither is network code. Any new hit fails here
/// and goes to the Head of Engineering before the list grows.
@Suite struct NetworkScanTests {
    static let repoRoot = contentRoot.deletingLastPathComponent()
    static let scanned = ["App", "CoachCore/Sources", "Shared", "LiveActivity"]

    /// Anything that opens a connection, loads a URL or hands one to the system.
    static let networkAPIs = [
        "URLSession", "URLRequest", "NWConnection", "NWListener", "NWBrowser", "CFStream",
        "getStreamsToHost", "WKWebView", "SFSafariViewController", "openURL", "Link(destination",
        "UIApplication.shared.open", "socket(", "MultipeerConnectivity", "CKContainer", "CloudKit",
        "MFMailCompose", "MessageUI", "webSocketTask", "http://", "https://",
    ]

    /// File (from the repo root) → the APIs it may use.
    static let allowed: [String: Set<String>] = [
        "App/Planner/MorningWeather.swift": ["URLSession"],
        "App/Meals/MealsHubView.swift": ["Link(destination"],
    ]

    private static func swiftFiles() -> [String] {
        let fm = FileManager.default
        return scanned.flatMap { dir -> [String] in
            let root = repoRoot.appendingPathComponent(dir)
            guard let walker = fm.enumerator(atPath: root.path) else { return [] }
            return walker.compactMap { $0 as? String }.filter { $0.hasSuffix(".swift") }.map { "\(dir)/\($0)" }
        }
    }

    @Test func onlyTheWeatherAndTheShopLinkUseTheNetwork() throws {
        let files = Self.swiftFiles()
        #expect(files.count > 50, "the scan found only \(files.count) Swift files; is the repo root right?")
        #expect(files.contains("App/Planner/MorningWeather.swift"))
        var hits: [String: Set<String>] = [:]
        for file in files {
            let text = try String(contentsOf: Self.repoRoot.appendingPathComponent(file), encoding: .utf8)
            for line in text.split(separator: "\n") {
                let code = line.trimmingCharacters(in: .whitespaces)
                if code.hasPrefix("//") { continue }    // comments may name APIs
                for api in Self.networkAPIs where code.contains(api) {
                    hits[file, default: []].insert(api)
                }
            }
        }
        for (file, apis) in hits.sorted(by: { $0.key < $1.key }) {
            let extra = apis.subtracting(Self.allowed[file] ?? [])
            #expect(extra.isEmpty, "\(file) uses \(extra.sorted()): not on the network allowlist")
        }
        // Both allowed uses are still there (if one goes, shrink the list).
        for (file, apis) in Self.allowed {
            #expect(apis.isSubset(of: hits[file] ?? []), "\(file) no longer uses \(apis.sorted())")
        }
    }

    /// The weather call carries only a fixed public route and constant fields.
    @Test func theForecastCarriesOnlyAFixedRouteAndConstants() throws {
        #expect(Set(RouteLocation.known.keys) == ["hyde-park"])
        for (_, place) in RouteLocation.known {
            let url = OpenMeteo.forecastURL(latitude: place.latitude, longitude: place.longitude)
            let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            #expect(parts.host == "api.open-meteo.com" && parts.scheme == "https")
            #expect(parts.user == nil && parts.password == nil && parts.fragment == nil)
            let items = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            #expect(items == [
                "latitude": String(place.latitude), "longitude": String(place.longitude),
                "hourly": "precipitation,precipitation_probability,temperature_2m,wind_gusts_10m,weather_code",
                "wind_speed_unit": "kmh", "timeformat": "unixtime", "timezone": "GMT", "forecast_days": "2",
            ])
        }
    }
}
