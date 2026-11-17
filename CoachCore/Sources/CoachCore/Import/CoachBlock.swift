import Foundation

// Board M4-02: the versioned block Claude replies with, and the owner imports
// from the clipboard. The block can set calories and protein, drop sessions
// for a week or more, and set dumbbell loads. It can never add or move a
// session, so it can't put one on Wednesday or add a fifth strength session
// (Advisor, 17 Nov 2026). Accepted blocks are stored by the app as a list and
// replayed by the rules engine; nothing else about them is stored.

/// One accepted Claude block, stamped with when it was imported and when it applies.
public struct CoachBlock: Codable, Sendable, Equatable {
    public static let format = "healthcoach-coach-block"
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// One or two lines from Claude, shown on Today.
    public var note: String?
    /// Daily calories from `effectiveFrom`, until the trend moves them on.
    public var dailyKcal: Int?
    public var proteinG: Int?
    /// Session ids left out, for `dropForWeeks` programme weeks from `effectiveFrom`.
    public var dropSessions: [String]
    public var dropForWeeks: Int
    /// Per-dumbbell weights, used until the owner next logs that exercise.
    public var loads: [Load]

    /// When the owner tapped Import.
    public var importedAt: Date?
    /// The start of the day after `importedAt` (plan §4.6: "applies from tomorrow").
    public var effectiveFrom: Date?

    public struct Load: Codable, Sendable, Equatable {
        public var exercise: String
        public var kg: Double

        public init(exercise: String, kg: Double) {
            self.exercise = exercise
            self.kg = kg
        }
    }

    public init(note: String? = nil, dailyKcal: Int? = nil, proteinG: Int? = nil,
                dropSessions: [String] = [], dropForWeeks: Int = 1, loads: [Load] = [],
                importedAt: Date? = nil, effectiveFrom: Date? = nil) {
        self.schemaVersion = Self.currentSchemaVersion
        self.note = note
        self.dailyKcal = dailyKcal
        self.proteinG = proteinG
        self.dropSessions = dropSessions
        self.dropForWeeks = dropForWeeks
        self.loads = loads
        self.importedAt = importedAt
        self.effectiveFrom = effectiveFrom
    }

    /// True if the block changes anything at all.
    public var changesSomething: Bool {
        dailyKcal != nil || proteinG != nil || !dropSessions.isEmpty || !loads.isEmpty
    }

    /// Blocks in force on `date` (effective on or before it), oldest first.
    public static func inForce(_ blocks: [CoachBlock], on date: Date, calendar: Calendar) -> [CoachBlock] {
        blocks
            .filter { ($0.effectiveFrom ?? .distantFuture) <= date }
            .sorted { ($0.effectiveFrom ?? .distantPast) < ($1.effectiveFrom ?? .distantPast) }
    }

    /// The latest block in force on `date`, for Today's note.
    public static func latest(_ blocks: [CoachBlock], on date: Date, calendar: Calendar) -> CoachBlock? {
        inForce(blocks, on: date, calendar: calendar).last
    }

    /// Session ids that imported blocks leave out on `date`. `dropForWeeks`
    /// counts whole programme weeks from the first Monday on or after
    /// `effectiveFrom`; the days before that Monday are covered too, so a
    /// block imported on Saturday still drops the whole of next week.
    public static func droppedSessions(_ blocks: [CoachBlock], on date: Date, start: Date,
                                       calendar: Calendar) -> Set<String> {
        guard let week = CalorieRules.week(of: date, start: start, calendar: calendar) else { return [] }
        var dropped = Set<String>()
        for block in inForce(blocks, on: date, calendar: calendar) where !block.dropSessions.isEmpty {
            guard let from = block.effectiveFrom,
                  let fromWeek = CalorieRules.week(of: from, start: start, calendar: calendar) else { continue }
            let startsOnMonday = calendar.isDate(from, inSameDayAs: calendar.date(
                byAdding: .day, value: (fromWeek - 1) * 7, to: calendar.startOfDay(for: start)) ?? start)
            let firstWholeWeek = startsOnMonday ? fromWeek : fromWeek + 1
            if week < firstWholeWeek + block.dropForWeeks { dropped.formUnion(block.dropSessions) }
        }
        return dropped
    }
}

// MARK: - Storage

extension CoachBlock {
    /// The app stores the accepted list as this JSON (one row, like the profile).
    public static func storedData(_ blocks: [CoachBlock]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(blocks)
    }

    /// Reads the stored list back. A list from a newer build is refused rather than half-read.
    public static func stored(from data: Data) throws -> [CoachBlock] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let blocks: [CoachBlock]
        do {
            blocks = try decoder.decode([CoachBlock].self, from: data)
        } catch {
            throw ContentError.unreadable(file: "Coach blocks", reason: describe(error))
        }
        if let newer = blocks.first(where: { $0.schemaVersion > currentSchemaVersion }) {
            throw ContentError.newerThanSupported(file: "Coach blocks", found: newer.schemaVersion,
                                                  supported: currentSchemaVersion)
        }
        return blocks
    }
}
