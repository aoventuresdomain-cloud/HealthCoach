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
    func load() throws -> Profile? {
        guard let record = try context.fetch(FetchDescriptor<ProfileRecord>()).first else { return nil }
        return try Profile.decoded(from: record.payload)
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

enum AppStore {
    /// On disk normally; in memory under `-uitest`, so every test starts clean.
    static func makeContainer(options: LaunchOptions = .current) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: options.isUITest)
        return try ModelContainer(for: ProfileRecord.self, configurations: configuration)
    }
}
