import Foundation
import Testing
@testable import CoachCore

/// Board M4-02: an imported Claude block changes next week's plan; a
/// malformed or wrong-version block is rejected with a plain message, and
/// last week's plan stays.
@Suite struct CoachImportTests {
    let f = CoachFixture()

    /// Saturday of week 3, 20:00: the block applies from Sunday.
    private var importedAt: Date { f.day(19, hour: 20) }

    private func reply(_ json: String) -> String {
        """
        Good week. Weight's flat, so trim a little and push the bench.

        ```
        \(CoachImport.beginMarker)
        \(json)
        \(CoachImport.endMarker)
        ```
        """
    }

    private func block(_ fields: String, version: Int = 1) -> String {
        reply("{\"format\": \"healthcoach-coach-block\", \"schemaVersion\": \(version)\(fields.isEmpty ? "" : ", " + fields)}")
    }

    private func outcome(_ text: String, into blocks: [CoachBlock] = [], at date: Date? = nil) throws -> CoachImport.Outcome {
        CoachImport.importing(text, into: blocks, programme: try f.phase1(), profile: f.profile(),
                              now: date ?? importedAt, calendar: f.calendar)
    }

    private func rejected(_ text: String, at date: Date? = nil) throws -> CoachImportError {
        let previous = [f.block(on: 5, kcal: 1_950)]
        let result = try outcome(text, into: previous, at: date)
        #expect(result.accepted == nil)
        #expect(result.blocks == previous) // last week's plan stays
        #expect(result.message.hasSuffix("Your plan hasn't changed."))
        return try #require(result.error)
    }

    // MARK: Accepted

    @Test func aGoodBlockIsStampedToApplyFromTomorrow() throws {
        let result = try outcome(block("""
            "note": "Trim 100 and push the bench.", "dailyKcal": 1900, "proteinG": 170,
            "dropSessions": ["full-body"], "dropForWeeks": 1,
            "loads": [{"exercise": "dumbbell-bench-press", "kg": 14}]
            """))
        let accepted = try #require(result.accepted)
        #expect(result.error == nil)
        #expect(result.message == "Imported. The new plan starts tomorrow.")
        #expect(result.blocks == [accepted])
        #expect(accepted.note == "Trim 100 and push the bench.")
        #expect(accepted.dailyKcal == 1_900)
        #expect(accepted.proteinG == 170)
        #expect(accepted.dropSessions == ["full-body"])
        #expect(accepted.loads == [.init(exercise: "dumbbell-bench-press", kg: 14)])
        #expect(accepted.importedAt == importedAt)
        #expect(accepted.effectiveFrom == f.day(20))
    }

    @Test func anImportedBlockChangesNextWeeksPlan() throws {
        let p = try f.phase1()
        let profile = f.profile()
        let flat = f.weights(to: 30) { _ in 82 }
        let blocks = try #require(try outcome(block("""
            "dailyKcal": 1950, "dropSessions": ["full-body"],
            "loads": [{"exercise": "dumbbell-bench-press", "kg": 14}]
            """)).accepted).map { [$0] } ?? []
        let monday = f.monday(4)

        let before = try #require(CoachReview.make(programme: p, profile: profile, history: [], weights: flat,
                                                   blocks: [], now: monday, calendar: f.calendar))
        let after = try #require(CoachReview.make(programme: p, profile: profile, history: [], weights: flat,
                                                  blocks: blocks, now: monday, calendar: f.calendar))
        // Calories: the block's 1,950 (one check skipped to settle) instead of the trend's 1,850.
        #expect(before.calories.kcal == 1_850)
        #expect(after.calories.kcal == 1_950)
        // Volume: Thursday's full-body is gone from next week.
        let plan = WeekPlanner.plan(weekStarting: monday, programme: p, profile: profile, answers: WeekAnswers(),
                                    dropping: after.droppedSessions, calendar: f.calendar)
        #expect(!plan.days.contains { $0.session?.sessionID == "full-body" })
        #expect(plan.days.contains { $0.session?.sessionID == "upper-a" })
        // Load: bench at 14 kg, from the bottom of its range.
        guard case let .strength(upperA) = try #require(p.sessions["upper-a"]) else { throw Problem() }
        let bench = try #require(upperA.blocks.flatMap(\.items).first { $0.exercise == "dumbbell-bench-press" })
        let rx = try #require(p.prescription(for: bench, week: 4, history: [], blocks: blocks, on: monday, calendar: f.calendar))
        #expect(rx.kg == 14)
        #expect(rx.reps == bench.reps?.min)
        #expect(rx.step == .coach)
        // Once logged at 14 kg, normal progression carries on from the log.
        let logged = SessionLog(programmeID: "phase-1", sessionID: "upper-a", week: 4, startedAt: monday,
                                finishedAt: monday, sets: [SetLog(exercise: "dumbbell-bench-press", setIndex: 0,
                                                                  reps: 8, kg: 14, asPrescribed: true)])
        let next = try #require(p.prescription(for: bench, week: 4, history: [logged], blocks: blocks,
                                               on: f.day(24), calendar: f.calendar))
        #expect(next.kg == 14)
        #expect(next.step == .climb)
    }

    @Test func proseAroundTheBlockAndNoFenceIsFine() throws {
        let text = "Here you go.\n\(CoachImport.beginMarker)\n{\"format\":\"healthcoach-coach-block\",\"schemaVersion\":1,\"dailyKcal\":2000}\n\(CoachImport.endMarker)\nGood luck."
        #expect(try outcome(text).accepted?.dailyKcal == 2_000)
    }

    @Test func aBareJSONBlockWithoutMarkersIsAccepted() throws {
        #expect(try outcome("{\"format\":\"healthcoach-coach-block\",\"schemaVersion\":1,\"proteinG\":160}").accepted != nil)
    }

    @Test func maintenanceWeeksTakeTheMaintenanceBand() throws {
        let inMaintenance = f.monday(13, hour: 20) // applies from Tuesday of week 13
        #expect(try outcome(block("\"dailyKcal\": 2500"), at: inMaintenance).accepted != nil)
        #expect(try rejected(block("\"dailyKcal\": 2000"), at: inMaintenance)
            == .invalid(["dailyKcal 2000 is outside 2,300–2,600"]))
    }

    // MARK: Rejected

    @Test func emptyOrUnrelatedClipboardIsRejected() throws {
        #expect(try rejected("") == .noBlock)
        #expect(try rejected("Thanks, Claude! See you next week.") == .noBlock)
        #expect(try rejected("{\"some\": \"other json\"}") == .noBlock)
        #expect(try rejected("\(CoachImport.beginMarker)\n{\"format\": \"healthcoach-coach-block\"") == .noBlock)
        #expect(CoachImportError.noBlock.errorDescription
            == "There's no HealthCoach block on the clipboard. In Claude, copy the whole reply, then tap Import again. Your plan hasn't changed.")
    }

    @Test func malformedJSONIsRejected() throws {
        #expect(try rejected(reply("{\"format\": \"healthcoach-coach-block\", \"schemaVersion\": 1, \"dailyKcal\": 19 00}"))
            == .unreadable("it isn't valid JSON"))
        #expect(try rejected(block("\"dailyKcal\": \"lots\"")) == .unreadable("dailyKcal: expected Double"))
        #expect(try rejected(block("\"dailyKcal\": 1900.5")) == .invalid(["dailyKcal must be a whole number"]))
        #expect(try rejected(reply("{\"format\": \"healthcoach-coach-block\", \"dailyKcal\": 1900}"))
            == .unreadable("\"schemaVersion\" is missing"))
    }

    @Test func wrongVersionOrFormatIsRejected() throws {
        let newer = try rejected(block("\"dailyKcal\": 1900", version: 2))
        #expect(newer == .newerVersion(found: 2))
        #expect(newer.errorDescription
            == "That block is format 2, but this app reads format 1. Ask Claude to use format 1, as the summary shows. Your plan hasn't changed.")
        #expect(try rejected(block("\"dailyKcal\": 1900", version: 0)) == .olderVersion(found: 0))
        #expect(try rejected(reply("{\"format\": \"healthcoach-meal-plan\", \"schemaVersion\": 1}"))
            == .wrongFormat("healthcoach-meal-plan"))
    }

    @Test func unknownFieldsAreRejectedNotIgnored() throws {
        #expect(try rejected(block("\"dailykcal\": 1900")) == .invalid(["\"dailykcal\" isn't a field this app knows"]))
    }

    @Test func aBlockThatChangesNothingIsRejected() throws {
        #expect(try rejected(block("\"note\": \"Keep going\"")) == .invalid(["it doesn't change anything"]))
    }

    @Test func caloriesAndProteinOutsideTheBandsAreRejected() throws {
        #expect(try rejected(block("\"dailyKcal\": 1700")) == .invalid(["dailyKcal 1700 is outside 1,850–2,200"]))
        #expect(try rejected(block("\"dailyKcal\": 2300")) == .invalid(["dailyKcal 2300 is outside 1,850–2,200"]))
        #expect(try rejected(block("\"proteinG\": 200")) == .invalid(["proteinG 200 is outside 140–180"]))
        #expect(try outcome(block("\"dailyKcal\": 1850, \"proteinG\": 140")).accepted != nil)
        #expect(try outcome(block("\"dailyKcal\": 2200, \"proteinG\": 180")).accepted != nil)
    }

    @Test func sessionsMustExistBeDroppableAndLeaveTwoStrength() throws {
        #expect(try rejected(block("\"dropSessions\": [\"basketball\"]")) == .invalid(["basketball is fixed and can't be dropped"]))
        #expect(try rejected(block("\"dropSessions\": [\"legs\"]")) == .invalid(["there's no session called legs"]))
        #expect(try rejected(block("\"dropSessions\": [\"upper-a\", \"full-body\"]"))
            == .invalid(["at least 2 strength sessions must stay each week"]))
        #expect(try rejected(block("\"dropSessions\": [\"run-1\"], \"dropForWeeks\": 5"))
            == .invalid(["dropForWeeks must be 1 to 4"]))
        #expect(try rejected(block("\"dropSessions\": [\"run-1\", \"run-1\"]"))
            == .invalid(["dropSessions names a session twice"]))
    }

    @Test func loadsMustBeRealDumbbellSettings() throws {
        #expect(try rejected(block("\"loads\": [{\"exercise\": \"dumbbell-bench-press\", \"kg\": 26}]"))
            == .invalid(["dumbbell-bench-press at 26 kg is outside 0–24 kg"]))
        #expect(try rejected(block("\"loads\": [{\"exercise\": \"dumbbell-bench-press\", \"kg\": 13}]"))
            == .invalid(["dumbbell-bench-press at 13 kg isn't a multiple of 2 kg"]))
        #expect(try rejected(block("\"loads\": [{\"exercise\": \"push-up\", \"kg\": 10}]"))
            == .invalid(["push-up isn't a dumbbell exercise in this programme"]))
        #expect(try rejected(block("\"loads\": [{\"exercise\": \"barbell-squat\", \"kg\": 10}]"))
            == .invalid(["barbell-squat isn't a dumbbell exercise in this programme"]))
        #expect(try outcome(block("\"loads\": [{\"exercise\": \"dumbbell-bench-press\", \"kg\": 24}]")).accepted != nil)
    }

    @Test func everyProblemIsListedAtOnce() throws {
        let error = try rejected(block("\"dailyKcal\": 1500, \"proteinG\": 100"))
        #expect(error == .invalid(["dailyKcal 1500 is outside 1,850–2,200", "proteinG 100 is outside 140–180"]))
        #expect(error.errorDescription
            == "The block wasn't used because dailyKcal 1500 is outside 1,850–2,200; proteinG 100 is outside 140–180. Your plan hasn't changed.")
    }

    @Test func hugeClipboardIsRefusedUnread() throws {
        #expect(try rejected(String(repeating: "x", count: CoachImport.maxTextBytes + 1)) == .tooLarge)
    }

    @Test func longNoteIsRejected() throws {
        let note = String(repeating: "a", count: 281)
        #expect(try rejected(block("\"note\": \"\(note)\", \"dailyKcal\": 1900"))
            == .invalid(["the note is longer than 280 characters"]))
    }

    // MARK: Storage

    @Test func storedListRoundTrips() throws {
        let blocks = [f.block(on: 5, kcal: 1_950, loads: [.init(exercise: "dumbbell-bench-press", kg: 12)]),
                      f.block(on: 12, drop: ["run-1"], weeks: 2)]
        #expect(try CoachBlock.stored(from: CoachBlock.storedData(blocks)) == blocks)
    }

    @Test func storedListFromANewerBuildIsRefused() throws {
        var newer = f.block(on: 5, kcal: 1_950)
        newer.schemaVersion = 2
        #expect(throws: ContentError.self) { try CoachBlock.stored(from: CoachBlock.storedData([newer])) }
    }

    struct Problem: Error {}
}
