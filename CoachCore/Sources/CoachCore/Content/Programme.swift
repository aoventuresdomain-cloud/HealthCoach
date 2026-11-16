import Foundation

/// `Content/programmes/phase-N.json`. Schema owner: Planner Engineer.
/// Per-week arrays are indexed by programme week, week 1 first.
public struct Programme: VersionedFormat, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let note: String?
    public let id: String
    public let phase: Int
    public let name: String
    public let weeks: Int
    public let maxSessionMinutes: Int
    public let warmUpMinutes: Int
    /// Smallest dumbbell increment, per dumbbell.
    public let loadStepKg: Double
    /// Heaviest dumbbell the owner has (decision D3); progression flags at it.
    public let dumbbellLimitKg: Double
    public let effort: [Effort]
    /// Plain-English description of each progression rule, keyed by rule.
    public let progressionRules: [String: String]
    public let fixed: [FixedEvent]
    public let placementRules: PlacementRules
    public let reducedWeek: ReducedWeek
    public let schedule: [ScheduleWeek]
    public let sessions: [String: Session]

    public struct Effort: Codable, Sendable, Equatable {
        public let week: Int
        public let mainSets: Int
        public let repsInReserve: Int
        public let cue: String
    }

    /// Something in the week the app plans around but doesn't run.
    public struct FixedEvent: Codable, Sendable, Equatable {
        public let id: String
        public let name: String
        public let kind: String
        public let day: Weekday
        public let time: String
        public let note: String?
    }

    public struct PlacementRules: Codable, Sendable, Equatable {
        public let neverOn: [Weekday]
        /// Fixed event id → sessions that must not fall the day before it.
        public let notTheDayBefore: [String: [String]]
        public let longSlot: Weekday
        public let outdoorSessions: [String]
    }

    /// Applied after two low recovery checks (M1-08).
    public struct ReducedWeek: Codable, Sendable, Equatable {
        public let trigger: String
        public let drop: [String]
        public let keep: [String]
    }

    public struct ScheduleWeek: Decodable, Sendable, Equatable {
        public let week: Int
        /// Session or fixed-event id for each day; nil = rest. All seven days present.
        public let days: [Weekday: String?]

        enum CodingKeys: String, CodingKey { case week, days }

        public init(week: Int, days: [Weekday: String?]) {
            self.week = week
            self.days = days
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            week = try container.decode(Int.self, forKey: .week)
            let dayContainer = try container.nestedContainer(keyedBy: DayKey.self, forKey: .days)
            var days: [Weekday: String?] = [:]
            for key in dayContainer.allKeys {
                guard let day = Weekday(rawValue: key.stringValue) else {
                    throw DecodingError.dataCorruptedError(forKey: key, in: dayContainer, debugDescription: "\"\(key.stringValue)\" is not a day")
                }
                days[day] = .some(try dayContainer.decodeIfPresent(String.self, forKey: key))
            }
            self.days = days
        }

        struct DayKey: CodingKey {
            let stringValue: String
            init?(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue: Int) { return nil }
        }
    }
}

// MARK: - Sessions

public enum Session: Decodable, Sendable, Equatable {
    case strength(StrengthSession)
    case runWalk(RunWalkSession)
    case circuit(CircuitSession)
    case walk(WalkSession)

    public var name: String {
        switch self {
        case let .strength(s): s.name
        case let .runWalk(s): s.name
        case let .circuit(s): s.name
        case let .walk(s): s.name
        }
    }

    enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: Decoder) throws {
        let kind = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .kind)
        switch kind {
        case "strength": self = .strength(try StrengthSession(from: decoder))
        case "run-walk": self = .runWalk(try RunWalkSession(from: decoder))
        case "circuit": self = .circuit(try CircuitSession(from: decoder))
        case "walk": self = .walk(try WalkSession(from: decoder))
        default:
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath + [CodingKeys.kind],
                debugDescription: "unknown session kind \"\(kind)\" (strength, run-walk, circuit, walk)"))
        }
    }
}

public struct IntRange: Codable, Sendable, Equatable {
    public let min: Int
    public let max: Int
}

public struct WarmUpItem: Codable, Sendable, Equatable {
    public let exercise: String
    public let perSide: Bool
    public let startKg: Double?
    public let reps: Int
}

public struct StrengthSession: Decodable, Sendable, Equatable {
    public let name: String
    public let warmUp: [WarmUpItem]
    public let blocks: [Block]
    /// Expected length per week, warm-up included.
    public let durationMinutes: [Int]
    public let warmUpMinutes: Int

    public struct Block: Codable, Sendable, Equatable {
        public let label: String
        public let restSeconds: Int
        public let items: [StrengthItem]
    }
}

public enum Progression: String, Codable, Sendable, CaseIterable {
    case double
    case repsTempoLoad = "reps-tempo-load"
    case repsTempo = "reps-tempo"
    case reps
    case time
    case timeThenLoad = "time-then-load"
    case repsThenGraduate = "reps-then-graduate"

    /// Time-based rules use `seconds`; the rest use `reps`.
    public var isTimed: Bool { self == .time || self == .timeThenLoad }

    /// Rules whose last step is one more load step (and so can hit the dumbbell limit).
    public var addsLoad: Bool { self == .double || self == .repsTempoLoad || self == .timeThenLoad }
}

public struct StrengthItem: Codable, Sendable, Equatable {
    public let exercise: String
    /// Working sets per week; 0 = not done that week.
    public let sets: [Int]
    public let repsInReserve: [Int]
    /// Exactly one of `reps` and `seconds` is set.
    public let reps: IntRange?
    public let seconds: IntRange?
    public let perSide: Bool
    /// Per dumbbell; nil = bodyweight.
    public let startKg: Double?
    public let tempo: String
    public let progression: Progression
    public let note: String?
    public let graduate: Graduate?
    public let autoSwap: AutoSwap?

    /// Move to a harder exercise once the rule is met (e.g. negatives → pull-ups).
    public struct Graduate: Codable, Sendable, Equatable {
        public let to: String
        public let when: String
        public let reps: IntRange
        public let then: String
    }

    /// Switch exercise mid-session, without asking, when the first set falls short.
    public struct AutoSwap: Codable, Sendable, Equatable {
        public let whenFirstSetRepsBelow: Int
        public let to: String
        public let startKg: Double?
        public let reps: IntRange
        public let from: String
        public let note: String?
    }
}

public struct RunWalkSession: Decodable, Sendable, Equatable {
    public let name: String
    public let outdoor: Bool
    public let route: String
    public let note: String?
    /// Only the weeks this session runs in.
    public let weeks: [Week]

    public struct Week: Codable, Sendable, Equatable {
        public let week: Int
        public let warmUpWalkMinutes: Int
        public let intervals: Intervals
        public let coolDownWalkMinutes: Int
        public let durationMinutes: Int
        public let jogMinutes: Double
        public let indoorSwap: IndoorSwap?
    }

    public struct Intervals: Codable, Sendable, Equatable {
        public let repeats: Int
        public let jogSeconds: Int
        public let walkSeconds: Int
    }

    public struct IndoorSwap: Codable, Sendable, Equatable {
        public let session: String
        public let rounds: Int
        public let coolDownMinutes: Int
        public let durationMinutes: Int
    }
}

public struct CircuitSession: Decodable, Sendable, Equatable {
    public let name: String
    /// Only used to replace a rained-off run.
    public let swapOnly: Bool?
    public let note: String?
    public let warmUp: [WarmUpItem]
    public let warmUpMinutes: Int
    public let round: Round
    public let roundMinutes: Int
    public let coolDown: String?

    public struct Round: Codable, Sendable, Equatable {
        public let workSeconds: Int
        public let restSeconds: Int
        public let items: [Item]
    }

    public struct Item: Codable, Sendable, Equatable {
        public let exercise: String
        public let startKg: Double?
        public let note: String?
    }
}

public struct WalkSession: Decodable, Sendable, Equatable {
    public let name: String
    public let optional: Bool
    /// Whether the walk gets an alarm.
    public let alarm: Bool
    public let durationMinutes: [Int]
    public let note: String?
}
