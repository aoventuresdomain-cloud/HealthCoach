import Foundation

/// `Content/exercises/exercises.json`. Schema owner: Planner Engineer.
public struct ExerciseCatalogue: VersionedFormat, Encodable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let note: String?
    public let mediaSource: MediaSource
    public let exercises: [Exercise]

    public struct MediaSource: Codable, Sendable, Equatable {
        public let provider: String
        public let owner: String
        public let format: String
        public let licence: String
    }

    public func exercise(_ id: String) -> Exercise? {
        exercises.first { $0.id == id }
    }
}

public struct Exercise: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let group: Group
    public let equipment: [Equipment]
    /// Where it appears, for people editing content; the app doesn't use it.
    public let usedIn: String?
    /// nil when no GIF exists; `substitute` then names whose GIF stands in.
    public let media: Media?
    /// The exercise whose GIF is shown when this one has none.
    public let substitute: String?
    /// What to do instead on pain or a kit problem.
    public let swap: String?
    /// N1: the pain areas it puts weight through. A check-in pain answer
    /// swaps it out for 7 days (`PainSwaps`). nil reads as none.
    public let loads: [PainArea]?
    public let callouts: Callouts

    public enum Group: String, Codable, Sendable, CaseIterable {
        case push, pull, legs, core, arms, shoulders
        case warmUp = "warm-up"
    }

    public enum Equipment: String, Codable, Sendable, CaseIterable {
        case bodyweight, dumbbells, bench, band
        case pullUpBar = "pull-up bar"
    }

    public struct Media: Codable, Sendable, Equatable {
        public let provider: String
        public let mediaId: String
        public let providerName: String
        public let url: String
        public let angle: Angle

        public enum Angle: String, Codable, Sendable {
            case front, side
            case rearThreeQuarter = "rear-three-quarter"
        }
    }

    /// Three short cues shown in the player. 12 words or fewer each.
    public struct Callouts: Codable, Sendable, Equatable {
        public let setup: String
        public let movement: String
        /// Phrased as the fix, not the fault.
        public let commonMistake: String
    }
}

extension ExerciseCatalogue {
    public static let maxCalloutWords = 12

    /// Rules the decoder can't check. Empty means valid.
    public func problems() -> [String] {
        var problems: [String] = []
        var seen = Set<String>()
        for exercise in exercises {
            if !seen.insert(exercise.id).inserted {
                problems.append("exercise id \(exercise.id) appears twice")
            }
            if !isSlug(exercise.id) {
                problems.append("\(exercise.id): id must be lower-case words joined by hyphens")
            }
            if exercise.equipment.isEmpty {
                problems.append("\(exercise.id): equipment is empty")
            }
            if exercise.media == nil && exercise.substitute == nil {
                problems.append("\(exercise.id): no media and no substitute, so the player would show nothing")
            }
            for (label, text) in [("setup", exercise.callouts.setup),
                                  ("movement", exercise.callouts.movement),
                                  ("commonMistake", exercise.callouts.commonMistake)] {
                let words = text.split(whereSeparator: \.isWhitespace).count
                if words == 0 {
                    problems.append("\(exercise.id): \(label) callout is empty")
                } else if words > Self.maxCalloutWords {
                    problems.append("\(exercise.id): \(label) callout has \(words) words (max \(Self.maxCalloutWords))")
                }
            }
        }
        let ids = Set(exercises.map(\.id))
        for exercise in exercises {
            for (label, ref) in [("substitute", exercise.substitute), ("swap", exercise.swap)] {
                guard let ref else { continue }
                if !ids.contains(ref) {
                    problems.append("\(exercise.id): \(label) \(ref) is not in the catalogue")
                } else if ref == exercise.id {
                    problems.append("\(exercise.id): \(label) points at itself")
                }
            }
            if let substitute = exercise.substitute, ids.contains(substitute), self.exercise(substitute)?.media == nil {
                problems.append("\(exercise.id): substitute \(substitute) has no media either")
            }
        }
        return problems
    }
}

func isSlug(_ text: String) -> Bool {
    !text.isEmpty
        && !text.hasPrefix("-") && !text.hasSuffix("-")
        && !text.contains("--")
        && text.allSatisfy { "abcdefghijklmnopqrstuvwxyz0123456789-".contains($0) }
}
