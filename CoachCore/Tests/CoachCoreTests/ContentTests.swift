import Foundation
import Testing
@testable import CoachCore

/// The repo's `Content/` folder, found from this file's path.
let contentRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // CoachCoreTests
    .deletingLastPathComponent() // Tests
    .deletingLastPathComponent() // CoachCore
    .deletingLastPathComponent() // repo root
    .appendingPathComponent("Content")

@Suite struct ContentFilesTests {
    /// Board M1-01: every file in Content/ is validated by a CoachCore test.
    /// A new kind of file must get a schema and a branch here, or this fails.
    @Test func everyJSONFileInContentIsKnownAndValid() throws {
        let library = try ContentLibrary.load(from: contentRoot)
        let enumerator = FileManager.default.enumerator(atPath: contentRoot.path)
        var unknown: [String] = []
        while let path = enumerator?.nextObject() as? String {
            guard path.hasSuffix(".json") else { continue }
            let known = path == ContentLibrary.exercisesPath
                || path == ContentLibrary.recipesPath || path == ContentLibrary.lunchOrdersPath
                || (path.hasPrefix(ContentLibrary.programmesFolder + "/")
                    && library.programmes[URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent] != nil)
            if !known { unknown.append(path) }
        }
        #expect(unknown.isEmpty, "Content files with no schema or validation: \(unknown)")
    }

    @Test func exercisesAreSchemaVersion1AndValid() throws {
        let library = try ContentLibrary.load(from: contentRoot)
        #expect(library.exercises.schemaVersion == 1)
        #expect(library.exercises.exercises.count >= 40)
        #expect(library.exercises.problems().isEmpty)
    }

    @Test func phaseOneLoadsWithSixWeeksAndEveryExerciseKnown() throws {
        let library = try ContentLibrary.load(from: contentRoot)
        let phase1 = try #require(library.programmes["phase-1"])
        #expect(phase1.schemaVersion == 1)
        #expect(phase1.weeks == 6)
        #expect(phase1.dumbbellLimitKg == 24)
        #expect(phase1.problems().isEmpty)
        #expect(phase1.problems(against: library.exercises).isEmpty)
        #expect(phase1.schedule.allSatisfy { $0.days.count == 7 })
    }
}

@Suite struct VersionedDecodingTests {
    private func catalogueJSON(version: Int) -> Data {
        Data("""
        {"schemaVersion": \(version),
         "mediaSource": {"provider": "p", "owner": "o", "format": "f", "licence": "l"},
         "exercises": [{"id": "push-up", "name": "Push-up", "group": "push", "equipment": ["bodyweight"],
           "media": {"provider": "p", "mediaId": "m", "providerName": "push up", "url": "u", "angle": "side"},
           "substitute": null, "swap": null,
           "callouts": {"setup": "Hands under shoulders.", "movement": "Lower, then push.", "commonMistake": "Keep hips level."}}]}
        """.utf8)
    }

    @Test func currentVersionDecodes() throws {
        let catalogue = try ExerciseCatalogue.decode(catalogueJSON(version: 1), file: "x.json")
        #expect(catalogue.exercises.first?.id == "push-up")
        #expect(catalogue.problems().isEmpty)
    }

    @Test func newerVersionIsRejectedWithAPlainMessage() {
        #expect(throws: ContentError.newerThanSupported(file: "x.json", found: 2, supported: 1)) {
            try ExerciseCatalogue.decode(catalogueJSON(version: 2), file: "x.json")
        }
        let message = ContentError.newerThanSupported(file: "x.json", found: 2, supported: 1).localizedDescription
        #expect(message.contains("newer version of HealthCoach"))
    }

    @Test func olderVersionIsRejected() {
        #expect(throws: ContentError.olderThanSupported(file: "x.json", found: 0, oldest: 1)) {
            try ExerciseCatalogue.decode(catalogueJSON(version: 0), file: "x.json")
        }
    }

    @Test func brokenJSONNamesTheFile() {
        do {
            _ = try ExerciseCatalogue.decode(Data("{ not json".utf8), file: "x.json")
            Issue.record("expected an error")
        } catch let error as ContentError {
            guard case let .unreadable(file, _) = error else { Issue.record("wrong error \(error)"); return }
            #expect(file == "x.json")
        } catch {
            Issue.record("wrong error type \(error)")
        }
    }

    @Test func wrongShapeNamesTheField() {
        let broken = Data(String(decoding: catalogueJSON(version: 1), as: UTF8.self)
            .replacingOccurrences(of: "\"equipment\": [\"bodyweight\"]", with: "\"equipment\": \"bodyweight\"").utf8)
        do {
            _ = try ExerciseCatalogue.decode(broken, file: "x.json")
            Issue.record("expected an error")
        } catch {
            #expect(error.localizedDescription.contains("equipment"))
        }
    }

    @Test func catalogueProblemsAreFound() throws {
        let bad = Data(String(decoding: catalogueJSON(version: 1), as: UTF8.self)
            .replacingOccurrences(of: "\"swap\": null", with: "\"swap\": \"no-such-exercise\"")
            .replacingOccurrences(of: "Keep hips level.", with: "one two three four five six seven eight nine ten eleven twelve thirteen").utf8)
        let problems = try ExerciseCatalogue.decode(bad, file: "x.json").problems()
        #expect(problems.contains { $0.contains("no-such-exercise") })
        #expect(problems.contains { $0.contains("13 words") })
    }
}

@Suite struct ProgrammeRuleTests {
    /// phase-1.json with one edit applied, to prove each rule bites.
    private func phase1(_ edit: (inout String) -> Void) throws -> Programme {
        var text = try String(contentsOf: contentRoot.appendingPathComponent("programmes/phase-1.json"), encoding: .utf8)
        edit(&text)
        return try Programme.decode(Data(text.utf8), file: "phase-1.json")
    }

    @Test func unknownSessionInScheduleIsCaught() throws {
        let programme = try phase1 { $0 = $0.replacingOccurrences(of: "\"monday\": \"upper-a\"", with: "\"monday\": \"upper-z\"") }
        #expect(programme.problems().contains { $0.contains("upper-z is not a session") })
    }

    @Test func sessionOnWednesdayIsCaught() throws {
        let programme = try phase1 { $0 = $0.replacingOccurrences(of: "\"wednesday\": \"basketball\"", with: "\"wednesday\": \"upper-a\"") }
        #expect(programme.problems().contains { $0.contains("no-session day") })
    }

    @Test func unknownExerciseIsCaughtAgainstTheCatalogue() throws {
        let library = try ContentLibrary.load(from: contentRoot)
        let programme = try phase1 { $0 = $0.replacingOccurrences(of: "\"exercise\": \"dumbbell-bench-press\"", with: "\"exercise\": \"bench-press-typo\"") }
        #expect(programme.problems(against: library.exercises).contains { $0.contains("bench-press-typo") })
    }

    @Test func weightOverTheDumbbellLimitIsCaught() throws {
        let programme = try phase1 { $0 = $0.replacingOccurrences(of: "\"startKg\": 10,", with: "\"startKg\": 30,") }
        #expect(programme.problems().contains { $0.contains("at most 24") })
    }

    @Test func unknownSessionKindIsUnreadable() {
        #expect(throws: ContentError.self) {
            try phase1 { $0 = $0.replacingOccurrences(of: "\"kind\": \"walk\"", with: "\"kind\": \"swim\"") }
        }
    }
}
