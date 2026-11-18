import CoachCore
import Foundation
import SwiftData

/// The one profile record, stored in SwiftData as CoachCore's versioned JSON.
/// CoachCore owns the format and its migrations (tested on Linux); SwiftData
/// only keeps the bytes, so a format change never needs a SwiftData migration.
@Model
final class ProfileRecord {
    var schemaVersion: Int
    var payload: Data
    var updatedAt: Date

    init(schemaVersion: Int, payload: Data, updatedAt: Date) {
        self.schemaVersion = schemaVersion
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@MainActor
final class ProfileStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// The stored profile, or nil before onboarding has saved one. Throws a
    /// plain message (from CoachCore) if the record is newer or broken.
    /// A Preferences edit whose day has come is applied (N3); one still
    /// waiting stays in `pending`, which the planners read day by day.
    func load(now: Date = AppClock.now()) throws -> Profile? {
        guard let record = try context.fetch(FetchDescriptor<ProfileRecord>()).first else { return nil }
        return try Profile.decoded(from: record.payload).effective(on: now, calendar: .coach)
    }

    /// N3: saves a Preferences edit. Today keeps its plan and alarms; the
    /// edit applies from tomorrow, never mid-day (`Profile.scheduling`).
    /// Reconcile the alarms afterwards, so tomorrow's onwards follow it.
    /// Returns the stored profile.
    @discardableResult
    func save(_ edited: Profile.Preferences, effectiveFrom now: Date = AppClock.now()) throws -> Profile {
        let current = try load(now: now) ?? Profile()
        let next = current.scheduling(edited, now: now, calendar: .coach)
        try save(next)
        return next
    }

    func save(_ profile: Profile) throws {
        let payload = try profile.encoded()
        if let record = try context.fetch(FetchDescriptor<ProfileRecord>()).first {
            record.schemaVersion = profile.schemaVersion
            record.payload = payload
            record.updatedAt = AppClock.now()
        } else {
            context.insert(ProfileRecord(schemaVersion: profile.schemaVersion, payload: payload, updatedAt: AppClock.now()))
        }
        try context.save()
    }
}

/// SwiftData schema versions. Each released shape of the models gets a new
/// `VersionedSchema` and a stage in `HealthCoachMigrationPlan`, so an update
/// never meets a store it can't read. Profile changes don't need one: the
/// profile is CoachCore's versioned JSON inside `ProfileRecord.payload`.
nonisolated enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [ProfileRecord.self, SessionLogRecord.self] }
}

nonisolated enum HealthCoachMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    /// Add `.lightweight(fromVersion:toVersion:)` or `.custom` stages here, oldest first.
    static var stages: [MigrationStage] { [] }
}

/// What happened when the store wouldn't open. The app keeps running either
/// way; Today shows a one-line notice (iOS Interface Engineer).
enum StoreRecovery: Equatable {
    /// The old store was moved aside (never deleted) and a fresh one opened.
    case startedFresh(keptCopyAt: URL)
    /// Nothing could be opened on disk: this session keeps data in memory only.
    case memoryOnly
}

enum AppStore {
    /// Set when `open()` had to recover; nil after a normal open.
    private(set) static var recovery: StoreRecovery?

    static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "HealthCoach.store")
    }

    /// Opens the store without crashing. In memory under `-uitest`, so every
    /// test starts clean. On disk otherwise; if the store won't open:
    /// - unreadable file (protected before first unlock, say): memory only for
    ///   this launch, and the store is left untouched for the next one;
    /// - readable but won't open (corrupt, or no migration path): the store is
    ///   moved aside, never deleted, and a fresh one opened.
    static func open(options: LaunchOptions = .current) -> ModelContainer {
        if options.isUITest {
            // Test-only: an in-memory store failing here is a broken simulator.
            return try! makeContainer(inMemory: true)
        }
        if let container = try? makeContainer(inMemory: false) {
            return container
        }
        let fm = FileManager.default
        if fm.isReadableFile(atPath: storeURL.path), let kept = moveStoreAside() {
            if let container = try? makeContainer(inMemory: false) {
                recovery = .startedFresh(keptCopyAt: kept)
                return container
            }
            // A fresh store failed too (disk full?): put the old one back.
            moveStore(from: kept, to: storeURL)
        }
        recovery = .memoryOnly
        // A fixed in-memory schema only fails if SwiftData itself is broken.
        return try! makeContainer(inMemory: true)
    }

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: storeURL)
        if !inMemory {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
        }
        return try ModelContainer(for: schema, migrationPlan: HealthCoachMigrationPlan.self,
                                  configurations: configuration)
    }

    /// Renames the store and its -wal/-shm files to `HealthCoach-unreadable-<time>.store`.
    /// Returns the kept copy's URL, or nil (store left in place) if it couldn't be moved.
    private static func moveStoreAside() -> URL? {
        let stamp = Int(Date().timeIntervalSince1970)
        let kept = storeURL.deletingLastPathComponent().appending(path: "HealthCoach-unreadable-\(stamp).store")
        return moveStore(from: storeURL, to: kept) ? kept : nil
    }

    /// Moves a store and its -wal/-shm files together; undoes a partial move.
    @discardableResult
    private static func moveStore(from: URL, to: URL) -> Bool {
        let fm = FileManager.default
        var moved: [String] = []
        for suffix in ["", "-wal", "-shm"] where fm.fileExists(atPath: from.path + suffix) {
            do {
                try fm.moveItem(atPath: from.path + suffix, toPath: to.path + suffix)
                moved.append(suffix)
            } catch {
                for done in moved { try? fm.moveItem(atPath: to.path + done, toPath: from.path + done) }
                return false
            }
        }
        return !moved.isEmpty
    }
}
