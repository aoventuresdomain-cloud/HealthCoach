import CoachCore
import Foundation

/// Named starting states for UI tests (`-fixture <name>`). Each is a JSON file
/// `fixture-<name>.json` in App/Testing/Fixtures, bundled with the app but only
/// read in Debug builds when the flag is given.
///
/// Shape: `{"profile": { …a Profile record… }}`. More keys (logged sessions,
/// alarm state) join as the features that need them land.
struct Fixture {
    let profile: Profile

    nonisolated enum LoadError: LocalizedError {
        case notFound(String)
        var errorDescription: String? {
            switch self {
            case let .notFound(name): "No fixture named \(name) (expected fixture-\(name).json in the app bundle)."
            }
        }
    }

    static func load(named name: String, bundle: Bundle = .main) throws -> Fixture {
        guard let url = bundle.url(forResource: "fixture-\(name)", withExtension: "json") else {
            throw LoadError.notFound(name)
        }
        let json = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url))
        let profileJSON = json["profile"] ?? .object(["schemaVersion": .number(1)])
        let profile = try Profile.decoded(from: JSONEncoder().encode(profileJSON))
        return Fixture(profile: profile)
    }
}
