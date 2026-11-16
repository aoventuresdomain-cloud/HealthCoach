import CoachCore
import Foundation
import SwiftData

/// Logged sessions (board M1-06), stored like the profile: CoachCore's
/// `SessionLog` as JSON bytes, so its format never needs a SwiftData migration.
@Model
final class SessionLogRecord {
    @Attribute(.unique) var id: UUID
    var sessionID: String
    var startedAt: Date
    var payload: Data

    init(id: UUID, sessionID: String, startedAt: Date, payload: Data) {
        self.id = id
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.payload = payload
    }
}

@MainActor
struct SessionLogStore {
    let context: ModelContext

    /// Inserts or replaces the log with the same id.
    func save(_ log: SessionLog) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(log)
        let id = log.id
        if let record = try context.fetch(FetchDescriptor<SessionLogRecord>(predicate: #Predicate { $0.id == id })).first {
            record.payload = payload
        } else {
            context.insert(SessionLogRecord(id: log.id, sessionID: log.sessionID, startedAt: log.startedAt, payload: payload))
        }
        try context.save()
    }

    /// Newest first.
    func all() throws -> [SessionLog] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = try context.fetch(FetchDescriptor<SessionLogRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
        return records.compactMap { try? decoder.decode(SessionLog.self, from: $0.payload) }
    }
}
