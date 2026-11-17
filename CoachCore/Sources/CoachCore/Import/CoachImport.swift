import Foundation

/// Why a pasted block was refused. Every message ends by saying the plan
/// hasn't changed (plan §4.6: "a bad block is rejected with a plain message,
/// and last week's plan stays").
public enum CoachImportError: Error, Equatable, LocalizedError {
    /// The clipboard has no block (or is empty).
    case noBlock
    /// More text than any real reply.
    case tooLarge
    /// A block, but for something else.
    case wrongFormat(String)
    case newerVersion(found: Int)
    case olderVersion(found: Int)
    /// Broken JSON or a field of the wrong type.
    case unreadable(String)
    /// Reads fine, but breaks a rule.
    case invalid([String])

    public static let unchanged = "Your plan hasn't changed."

    public var errorDescription: String? {
        let detail: String = switch self {
        case .noBlock:
            "There's no HealthCoach block on the clipboard. In Claude, copy the whole reply, then tap Import again."
        case .tooLarge:
            "That's too much text to be a HealthCoach block. Copy just Claude's reply, then tap Import again."
        case let .wrongFormat(found):
            "That block is \"\(found)\", not a HealthCoach coach block."
        case let .newerVersion(found):
            "That block is format \(found), but this app reads format \(CoachBlock.currentSchemaVersion). Ask Claude to use format \(CoachBlock.currentSchemaVersion), as the summary shows."
        case let .olderVersion(found):
            "That block is format \(found), which this app no longer reads. Ask Claude to use format \(CoachBlock.currentSchemaVersion), as the summary shows."
        case let .unreadable(reason):
            "The block couldn't be read (\(reason)). Ask Claude to send it again exactly as the summary shows."
        case let .invalid(problems):
            "The block wasn't used because " + problems.joined(separator: "; ") + "."
        }
        return detail + " " + Self.unchanged
    }
}

/// Reads and checks a Claude block from the clipboard (board M4-02).
public enum CoachImport {
    public static let beginMarker = "BEGIN HEALTHCOACH BLOCK"
    public static let endMarker = "END HEALTHCOACH BLOCK"
    /// Any real reply is far smaller; anything bigger is refused unread.
    public static let maxTextBytes = 64 * 1024
    public static let maxNoteLength = 280
    public static let maxDropForWeeks = 4
    /// Strength sessions that must stay in any week (Advisor floor for a cut).
    public static let minimumStrengthSessionsKept = 2

    /// The keys Claude may send. Anything else is refused, so a typo can't be silently ignored.
    static let allowedKeys: Set<String> = [
        "format", "schemaVersion", "note", "dailyKcal", "proteinG", "dropSessions", "dropForWeeks", "loads",
    ]

    /// Accept or refuse `text` against the current list. On refusal the list
    /// comes back unchanged, so last week's plan stays.
    public static func importing(_ text: String, into blocks: [CoachBlock], programme: Programme,
                                 profile: Profile, now: Date, calendar: Calendar = .current) -> Outcome {
        do {
            let block = try parse(text, programme: programme, profile: profile, now: now, calendar: calendar)
            return Outcome(blocks: blocks + [block], accepted: block, error: nil)
        } catch let error as CoachImportError {
            return Outcome(blocks: blocks, accepted: nil, error: error)
        } catch {
            return Outcome(blocks: blocks, accepted: nil, error: .unreadable(String(describing: error)))
        }
    }

    public struct Outcome: Sendable, Equatable {
        /// The list to store: one longer if accepted, otherwise unchanged.
        public let blocks: [CoachBlock]
        public let accepted: CoachBlock?
        public let error: CoachImportError?

        /// The one line the app shows after Import.
        public var message: String {
            if let error { return error.errorDescription ?? CoachImportError.unchanged }
            return "Imported. The new plan starts tomorrow."
        }
    }

    /// The block in `text`, checked and stamped, or a plain reason it was refused.
    public static func parse(_ text: String, programme: Programme, profile: Profile,
                             now: Date, calendar: Calendar = .current) throws -> CoachBlock {
        guard text.utf8.count <= maxTextBytes else { throw CoachImportError.tooLarge }
        guard let json = extract(from: text) else { throw CoachImportError.noBlock }
        guard let data = json.data(using: .utf8),
              let tree = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            throw CoachImportError.unreadable("it isn't valid JSON")
        }
        guard case let .object(fields) = tree else { throw CoachImportError.unreadable("it isn't a JSON object") }

        guard case let .string(format)? = fields["format"] else {
            throw CoachImportError.unreadable("\"format\" is missing")
        }
        guard format == CoachBlock.format else { throw CoachImportError.wrongFormat(format) }
        guard case let .number(versionNumber)? = fields["schemaVersion"],
              versionNumber == versionNumber.rounded() else {
            throw CoachImportError.unreadable("\"schemaVersion\" is missing")
        }
        let version = Int(versionNumber)
        if version > CoachBlock.currentSchemaVersion { throw CoachImportError.newerVersion(found: version) }
        if version < CoachBlock.currentSchemaVersion { throw CoachImportError.olderVersion(found: version) }

        let unknown = fields.keys.filter { !allowedKeys.contains($0) }.sorted()
        if !unknown.isEmpty {
            throw CoachImportError.invalid(unknown.map { "\"\($0)\" isn't a field this app knows" })
        }

        let wire: Wire
        do {
            wire = try JSONDecoder().decode(Wire.self, from: data)
        } catch {
            throw CoachImportError.unreadable(describe(error))
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        // Whole numbers only; a fraction is refused, not rounded.
        let fractional = [("dailyKcal", wire.dailyKcal), ("proteinG", wire.proteinG)]
            .filter { $0.1.map { $0 != $0.rounded() || abs($0) > 100_000 } ?? false }
            .map { "\($0.0) must be a whole number" }
        if !fractional.isEmpty { throw CoachImportError.invalid(fractional) }
        let note = wire.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let block = CoachBlock(
            note: note?.isEmpty == true ? nil : note,
            dailyKcal: wire.dailyKcal.map { Int($0) }, proteinG: wire.proteinG.map { Int($0) },
            dropSessions: wire.dropSessions ?? [], dropForWeeks: wire.dropForWeeks ?? 1,
            loads: (wire.loads ?? []).map { CoachBlock.Load(exercise: $0.exercise, kg: $0.kg) },
            importedAt: now, effectiveFrom: tomorrow)

        let problems = validate(block, programme: programme, profile: profile, calendar: calendar)
        if !problems.isEmpty { throw CoachImportError.invalid(problems) }
        return block
    }

    /// The JSON between the markers, with any code fence around it removed.
    /// Without markers, a reply that is only the JSON object is accepted too.
    static func extract(from text: String) -> String? {
        var body: Substring
        if let begin = text.range(of: beginMarker) {
            guard let end = text.range(of: endMarker, range: begin.upperBound..<text.endIndex) else { return nil }
            body = text[begin.upperBound..<end.lowerBound]
        } else {
            body = Substring(text)
        }
        guard let open = body.firstIndex(of: "{"), let close = body.lastIndex(of: "}"), open < close else {
            return nil
        }
        body = body[open...close]
        // Without markers, only take it if it claims to be our format.
        if text.range(of: beginMarker) == nil, !body.contains(CoachBlock.format) { return nil }
        return String(body)
    }

    /// What Claude sends. Types are checked here; rules in `validate`.
    struct Wire: Decodable {
        let note: String?
        let dailyKcal: Double?
        let proteinG: Double?
        let dropSessions: [String]?
        let dropForWeeks: Int?
        let loads: [WireLoad]?

        struct WireLoad: Decodable {
            let exercise: String
            let kg: Double
        }
    }

    /// Every rule a block breaks, in plain words; empty means it's safe to apply.
    static func validate(_ block: CoachBlock, programme: Programme, profile: Profile,
                         calendar: Calendar) -> [String] {
        var problems: [String] = []
        if !block.changesSomething {
            problems.append("it doesn't change anything")
        }
        if let note = block.note, note.count > maxNoteLength {
            problems.append("the note is longer than \(maxNoteLength) characters")
        }

        // Calories: the band depends on whether the block starts in a maintenance week.
        if let kcal = block.dailyKcal {
            let week = profile.programme.startDate.flatMap { start in
                block.effectiveFrom.flatMap { CalorieRules.week(of: $0, start: start, calendar: calendar) }
            }
            let maintenance = week.map(CalorieRules.isMaintenance) ?? false
            let band = maintenance ? CalorieRules.importMaintenanceBand : CalorieRules.importCutBand
            if !band.contains(kcal) {
                problems.append("dailyKcal \(kcal) is outside \(CoachText.thousands(band.lowerBound))–\(CoachText.thousands(band.upperBound))")
            }
        }
        if let protein = block.proteinG, !CalorieRules.importProteinG.contains(protein) {
            let band = CalorieRules.importProteinG
            problems.append("proteinG \(protein) is outside \(band.lowerBound)–\(band.upperBound)")
        }

        // Sessions: only real session ids, never fixed events, and enough strength left.
        if !block.dropSessions.isEmpty {
            if Set(block.dropSessions).count != block.dropSessions.count {
                problems.append("dropSessions names a session twice")
            }
            var strength = Set<String>()
            for (id, session) in programme.sessions {
                if case .strength = session { strength.insert(id) }
            }
            for id in block.dropSessions where programme.sessions[id] == nil {
                if programme.fixed.contains(where: { $0.id == id }) {
                    problems.append("\(id) is fixed and can't be dropped")
                } else {
                    problems.append("there's no session called \(id)")
                }
            }
            let kept = strength.subtracting(block.dropSessions).count
            if kept < min(minimumStrengthSessionsKept, strength.count) {
                problems.append("at least \(minimumStrengthSessionsKept) strength sessions must stay each week")
            }
            if !(1...maxDropForWeeks).contains(block.dropForWeeks) {
                problems.append("dropForWeeks must be 1 to \(maxDropForWeeks)")
            }
        } else if block.dropForWeeks != 1 {
            problems.append("dropForWeeks is set but dropSessions is empty")
        }

        // Loads: dumbbell exercises in this programme, on a real dumbbell setting.
        if !block.loads.isEmpty {
            let weighted = programme.dumbbellExercises
            let limit = min(programme.dumbbellLimitKg, profile.training.dumbbellMaxKg)
            var seen = Set<String>()
            for load in block.loads {
                if !seen.insert(load.exercise).inserted {
                    problems.append("\(load.exercise) has two loads")
                    continue
                }
                guard weighted.contains(load.exercise) else {
                    problems.append("\(load.exercise) isn't a dumbbell exercise in this programme")
                    continue
                }
                let steps = load.kg / programme.loadStepKg
                if load.kg <= 0 || load.kg > limit {
                    problems.append("\(load.exercise) at \(CoachText.kg(load.kg)) is outside 0–\(CoachText.kg(limit))")
                } else if abs(steps - steps.rounded()) > 0.001 {
                    problems.append("\(load.exercise) at \(CoachText.kg(load.kg)) isn't a multiple of \(CoachText.kg(programme.loadStepKg))")
                }
            }
        }
        return problems
    }
}

extension Programme {
    /// Exercises done with dumbbells (they have a starting weight), including auto-swaps.
    public var dumbbellExercises: Set<String> {
        var ids = Set<String>()
        for session in sessions.values {
            guard case let .strength(s) = session else { continue }
            for item in s.blocks.flatMap(\.items) {
                if item.startKg != nil { ids.insert(item.exercise) }
                if let swap = item.autoSwap, swap.startKg != nil { ids.insert(swap.to) }
            }
        }
        return ids
    }
}
