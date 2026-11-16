import Foundation

/// The owner's one versioned profile record (plan §1, §5; requirements §12).
/// Everything specific to the owner lives here, not in code. The app stores
/// it in SwiftData as encoded JSON with its version alongside, so CoachCore
/// owns the format and its migrations and tests them on Linux.
///
/// Additive changes (a new optional field, or one with a default) keep the
/// version and decode old records unchanged. A rename or a change of meaning
/// bumps `currentSchemaVersion` and adds a step to `migrate`.
public struct Profile: VersionedFormat, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int = Profile.currentSchemaVersion
    /// False until the owner taps "Looks right" in onboarding (M1-04).
    public var confirmed: Bool = false

    public var about = About()
    public var goal = Goal()
    public var schedule = Schedule()
    public var training = Training()
    public var coach = Coach()
    public var programme = ProgrammeState()

    public init() {}

    public struct About: Codable, Sendable, Equatable {
        public var name: String?
        public var heightCm: Double?
        public var weightKg: Double?
        /// "Anything that hurts". Empty = nothing; exercises are swapped for
        /// their named `swap` where an entry applies (M1-04).
        public var painAreas: [String] = []
        public init() {}
    }

    public struct Goal: Codable, Sendable, Equatable {
        public var target: Target = .leanAndStrong
        public var phaseWeeks: Int = 6
        public init() {}

        public enum Target: String, Codable, Sendable, CaseIterable {
            case leanAndDefined = "lean-and-defined"
            case leanAndStrong = "lean-and-strong"
            case buildMuscle = "build-muscle"
            case generalFitness = "general-fitness"
        }
    }

    public struct Schedule: Codable, Sendable, Equatable {
        /// One sleep rule (M1-03 design): lights out = alarm − sleep − fall-asleep.
        public var sleepHours: Double = 7.5
        public var fallAsleepMinutes: Int = 15
        public var windDownMinutes: Int = 30
        public var latestBedtime = TimeOfDay(hour: 23, minute: 30)
        public var earliestWake = TimeOfDay(hour: 5, minute: 45)
        public var workStart = TimeOfDay(hour: 9, minute: 0)
        public var workEnd = TimeOfDay(hour: 18, minute: 0)
        public var trainingWindows: TrainingWindows = .both
        public var longSessionDay: Weekday = .sunday
        public init() {}

        public enum TrainingWindows: String, Codable, Sendable, CaseIterable {
            case morning, evening, both
        }
    }

    public struct Training: Codable, Sendable, Equatable {
        public var maxSessionMinutes: Int = 45
        public var dumbbellMaxKg: Double = 24
        public var hasBench = true
        public var hasPullUpBar = true
        public var voiceCues = true
        public var counting: Counting = .tap
        public init() {}

        public enum Counting: String, Codable, Sendable, CaseIterable {
            case tap, voice, both
        }
    }

    public struct Coach: Codable, Sendable, Equatable {
        public var checkInDay: Weekday = .sunday
        public var checkInTime = TimeOfDay(hour: 18, minute: 0)
        public var moodCheck = true
        public var quietFrom = TimeOfDay(hour: 22, minute: 30)
        public var quietUntil = TimeOfDay(hour: 6, minute: 0)
        public init() {}
    }

    /// Where the owner is in the plan.
    public struct ProgrammeState: Codable, Sendable, Equatable {
        public var programmeID = "phase-1"
        /// Monday of programme week 1, in the owner's calendar. nil until onboarding.
        public var startDate: Date?
        public init() {}
    }
}

extension Profile {
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(self)
    }

    /// Decodes a stored record. Any field missing at any depth takes its
    /// default (the stored JSON is laid over a default profile first), so
    /// additive changes need no migration step. Migrations for breaking
    /// changes go in `migrate` before that.
    public static func decoded(from data: Data) throws -> Profile {
        let file = "Profile"
        // Version check first, with the usual plain messages.
        struct Header: Decodable { let schemaVersion: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            throw ContentError.unreadable(file: file, reason: "no schemaVersion")
        }
        if header.schemaVersion > currentSchemaVersion {
            throw ContentError.newerThanSupported(file: file, found: header.schemaVersion, supported: currentSchemaVersion)
        }
        if header.schemaVersion < oldestSchemaVersion {
            throw ContentError.olderThanSupported(file: file, found: header.schemaVersion, oldest: oldestSchemaVersion)
        }
        do {
            let stored = try migrate(JSONDecoder().decode(JSONValue.self, from: data), from: header.schemaVersion)
            let base = try JSONDecoder().decode(JSONValue.self, from: Profile().encoded())
            var merged = base.merging(stored)
            merged["schemaVersion"] = .number(Double(currentSchemaVersion))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Profile.self, from: JSONEncoder().encode(merged))
        } catch {
            throw ContentError.unreadable(file: file, reason: describe(error))
        }
    }

    /// One step per breaking version change, oldest first. None yet.
    static func migrate(_ json: JSONValue, from version: Int) throws -> JSONValue {
        json
    }
}
