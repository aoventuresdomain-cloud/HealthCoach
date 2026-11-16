import Foundation

/// Everything in `Content/`, decoded and checked together. The app loads it
/// from its bundle; CoachCore tests load it straight from the repo, so every
/// content change is validated by `swift test`.
public struct ContentLibrary: Sendable {
    public let exercises: ExerciseCatalogue
    /// Keyed by programme id ("phase-1").
    public let programmes: [String: Programme]

    public static let exercisesPath = "exercises/exercises.json"
    public static let programmesFolder = "programmes"

    /// Loads and validates. Throws the first file's error, so a broken file
    /// is named rather than half-loaded.
    public static func load(from root: URL) throws -> ContentLibrary {
        let exercises = try loadFile(ExerciseCatalogue.self, root.appendingPathComponent(exercisesPath), name: exercisesPath)
        try require(exercises.problems(), file: exercisesPath)

        var programmes: [String: Programme] = [:]
        let folder = root.appendingPathComponent(programmesFolder)
        for url in try jsonFiles(in: folder) {
            let name = "\(programmesFolder)/\(url.lastPathComponent)"
            let programme = try loadFile(Programme.self, url, name: name)
            var problems = programme.problems() + programme.problems(against: exercises)
            if url.deletingPathExtension().lastPathComponent != programme.id {
                problems.append("file name should match id \(programme.id)")
            }
            if programmes[programme.id] != nil {
                problems.append("another file already has id \(programme.id)")
            }
            try require(problems, file: name)
            programmes[programme.id] = programme
        }
        return ContentLibrary(exercises: exercises, programmes: programmes)
    }

    static func loadFile<T: VersionedFormat>(_ type: T.Type, _ url: URL, name: String) throws -> T {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ContentError.unreadable(file: name, reason: "file missing or unreadable")
        }
        return try T.decode(data, file: name)
    }

    static func require(_ problems: [String], file: String) throws {
        if !problems.isEmpty { throw ContentError.invalid(file: file, problems: problems) }
    }

    static func jsonFiles(in folder: URL) throws -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasSuffix(".json") }.sorted().map { folder.appendingPathComponent($0) }
    }
}
