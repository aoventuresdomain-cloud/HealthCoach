import Foundation

/// Everything in `Content/`, decoded and checked together. The app loads it
/// from its bundle; CoachCore tests load it straight from the repo, so every
/// content change is validated by `swift test`.
public struct ContentLibrary: Sendable {
    public let exercises: ExerciseCatalogue
    /// Keyed by programme id ("phase-1").
    public let programmes: [String: Programme]
    /// Recipes, ingredients, box night and daily targets (M3).
    public let nutrition: NutritionContent
    /// Office-day lunch orders (M3).
    public let lunchOrders: LunchOrders
    /// Named run loops, keyed by route id ("hyde-park") (N10).
    public let runLoops: [String: RunLoops]

    public static let exercisesPath = "exercises/exercises.json"
    public static let programmesFolder = "programmes"
    public static let recipesPath = "recipes/recipes.json"
    public static let lunchOrdersPath = "lunch-orders.json"
    public static let routesFolder = "routes"

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
        let nutrition = try loadFile(NutritionContent.self, root.appendingPathComponent(recipesPath), name: recipesPath)
        try require(nutrition.problems(), file: recipesPath)
        let lunchOrders = try loadFile(LunchOrders.self, root.appendingPathComponent(lunchOrdersPath), name: lunchOrdersPath)
        try require(lunchOrders.problems(), file: lunchOrdersPath)

        var runLoops: [String: RunLoops] = [:]
        for url in try jsonFiles(in: root.appendingPathComponent(routesFolder)) {
            let name = "\(routesFolder)/\(url.lastPathComponent)"
            let loops = try loadFile(RunLoops.self, url, name: name)
            var problems = loops.problems()
            if runLoops[loops.route] != nil { problems.append("another file already has route \(loops.route)") }
            try require(problems, file: name)
            runLoops[loops.route] = loops
        }
        try require(phaseProblems(Array(programmes.values)), file: programmesFolder)
        // C6: each phase knows the ones before it, so its loads carry on from theirs.
        let ordered = programmes.values.sorted { $0.phase < $1.phase }
        for programme in ordered {
            programmes[programme.id]?.earlierPhases = ordered.filter { $0.phase < programme.phase }
        }
        return ContentLibrary(exercises: exercises, programmes: programmes, nutrition: nutrition, lunchOrders: lunchOrders,
                              runLoops: runLoops)
    }

    /// C6: the phases follow on, week for week: phase N + 1 starts the plan
    /// week after phase N ends, from plan week 1.
    static func phaseProblems(_ programmes: [Programme]) -> [String] {
        var problems: [String] = []
        var next = 1
        for programme in programmes.sorted(by: { $0.phase < $1.phase }) {
            if programme.planWeeks.lowerBound != next {
                problems.append("\(programme.id) starts at plan week \(programme.planWeeks.lowerBound), expected \(next)")
            }
            next = programme.planWeeks.upperBound + 1
        }
        return problems
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

// MARK: - C6 · Phases in order

extension ContentLibrary {
    /// Every programme, Phase 1 first.
    public var phases: [Programme] { programmes.values.sorted { $0.phase < $1.phase } }

    /// The programme in force on `date`, counting plan weeks from `start`
    /// (Phase 1's Monday): Phase 1 for weeks 1–6 (and before the start),
    /// Phase 2 for 7–14, Phase 3 for 15–20, and the last phase after that
    /// (it holds at its last week, E13). Nil only with no programmes.
    public func programme(on date: Date, start: Date, calendar: Calendar = .current) -> Programme? {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        let planWeek = days / 7 + 1
        let ordered = phases
        return ordered.last { $0.planWeeks.lowerBound <= planWeek } ?? ordered.first
    }

    /// The programme for `profile` on `date`: by date once the programme has
    /// a start, else the profile's own (`programmeID`).
    public func programme(for profile: Profile, on date: Date, calendar: Calendar = .current) -> Programme? {
        guard let start = profile.programme.startDate else { return programmes[profile.programme.programmeID] }
        return programme(on: date, start: start, calendar: calendar)
    }

}
