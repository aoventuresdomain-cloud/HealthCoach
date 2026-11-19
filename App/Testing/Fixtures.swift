import CoachCore
import Foundation

/// Named starting states for UI tests (`-fixture <name>`). Each is a JSON file
/// `fixture-<name>.json` in App/Testing/Fixtures, bundled with the app but only
/// read in Debug builds when the flag is given.
///
/// Shape: `{"profile": { …a Profile record… }, "logs": [{"sessionID", "week",
/// "startedAt" (ISO 8601)}], "weekAnswers": {"yyyy-MM-dd" (a Monday): WeekAnswers}}`.
/// `logs` is optional (`"allDone": true` fills every set as prescribed): sessions already done, so the planner (E13) doesn't
/// move them. A log that starts after `now` (the `-now` clock) is left out, so
/// one fixture can script a whole week: each launch sees only what is done by then. `weekAnswers` is optional: the Sunday prompt's answers for those
/// weeks. `photoDays` (ISO 8601) is optional: drawn photo sets
/// saved on those days (N7). `health` is optional: fixed weigh-ins and steps (`FixedHealthReader`)
/// in place of the generic sample data (A12). More keys join as features need them.
struct Fixture {
    let profile: Profile
    var logs: [SessionLog] = []
    /// Monday ("yyyy-MM-dd") → that week's answers.
    var weekAnswers: [String: WeekAnswers] = [:]
    /// Fixed Health data, read by BodyStats in UI-test mode instead of the sample reader.
    var health: FixedHealthReader?
    /// N7: days with a (drawn) photo set, oldest first.
    var photoDays: [Date] = []

    private struct Logs: Decodable {
        struct Entry: Decodable {
            let sessionID: String
            let week: Int
            let startedAt: Date
            /// C6: true fills the log with every set done as prescribed, so
            /// the next session progresses from it.
            let allDone: Bool?
        }
        let logs: [Entry]?
        let weekAnswers: [String: WeekAnswers]?
        let health: FixedHealthReader?
        let photoDays: [Date]?
    }

    nonisolated enum LoadError: LocalizedError {
        case notFound(String)
        case badWeek(String)
        var errorDescription: String? {
            switch self {
            case let .notFound(name): "No fixture named \(name) (expected fixture-\(name).json in the app bundle)."
            case let .badWeek(key): "Fixture week \(key) isn't a yyyy-MM-dd date."
            }
        }
    }

    /// Saves the week answers in `store`, after clearing it so nothing leaks
    /// from an earlier launch (UserDefaults outlives the in-memory store).
    func applyWeekAnswers(to store: WeekAnswersStore, calendar: Calendar = .current) throws {
        store.removeAll()
        for (key, answers) in weekAnswers {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3,
                  let monday = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
                throw LoadError.badWeek(key)
            }
            store.save(answers, weekStarting: monday, calendar: calendar)
        }
    }

    static func load(named name: String, now: Date = AppClock.now(), bundle: Bundle = .main) throws -> Fixture {
        guard let url = bundle.url(forResource: "fixture-\(name)", withExtension: "json") else {
            throw LoadError.notFound(name)
        }
        let json = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url))
        let profileJSON = json["profile"] ?? .object(["schemaVersion": .number(1)])
        let profile = try Profile.decoded(from: JSONEncoder().encode(profileJSON))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let extras = try decoder.decode(Logs.self, from: Data(contentsOf: url))
        let entries = (extras.logs ?? []).filter { $0.startedAt <= now }.sorted { $0.startedAt < $1.startedAt }
        var programme: Programme?
        if entries.contains(where: { $0.allDone == true }) {
            programme = try BundledContent.load(bundle: bundle).programmes[profile.programme.programmeID]
        }
        var logs: [SessionLog] = []
        for entry in entries {
            var log = SessionLog(programmeID: profile.programme.programmeID, sessionID: entry.sessionID, week: entry.week,
                                 startedAt: entry.startedAt, finishedAt: entry.startedAt.addingTimeInterval(45 * 60))
            if entry.allDone == true, let programme,
               let script = WorkoutScript.make(sessionID: entry.sessionID, programme: programme,
                                               week: entry.week, history: logs) {
                log.sets = script.sets.map { $0.prescribedLog() }
            }
            logs.append(log)
        }
        return Fixture(profile: profile, logs: logs, weekAnswers: extras.weekAnswers ?? [:], health: extras.health,
                       photoDays: (extras.photoDays ?? []).filter { $0 <= now }.sorted())
    }
}
