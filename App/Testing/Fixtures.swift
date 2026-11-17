import CoachCore
import Foundation

/// Named starting states for UI tests (`-fixture <name>`). Each is a JSON file
/// `fixture-<name>.json` in App/Testing/Fixtures, bundled with the app but only
/// read in Debug builds when the flag is given.
///
/// Shape: `{"profile": { …a Profile record… }, "logs": [{"sessionID", "week",
/// "startedAt" (ISO 8601)}]}`. `logs` is optional: sessions already done, so
/// the planner (E13) doesn't move them. More keys join as features need them.
struct Fixture {
    let profile: Profile
    var logs: [SessionLog] = []

    private struct Logs: Decodable {
        struct Entry: Decodable {
            let sessionID: String
            let week: Int
            let startedAt: Date
        }
        let logs: [Entry]?
    }

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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let logs = try decoder.decode(Logs.self, from: Data(contentsOf: url)).logs ?? []
        return Fixture(profile: profile, logs: logs.map {
            SessionLog(programmeID: profile.programme.programmeID, sessionID: $0.sessionID, week: $0.week,
                       startedAt: $0.startedAt, finishedAt: $0.startedAt.addingTimeInterval(45 * 60))
        })
    }
}
