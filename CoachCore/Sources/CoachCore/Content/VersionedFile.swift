import Foundation

/// Every stored format (content files, the profile record) carries a
/// `schemaVersion`. A file from a newer build, or one that won't decode, is
/// rejected with a plain message rather than half-loaded.
public enum ContentError: Error, Equatable, LocalizedError {
    /// The file says it's a newer format than this build understands.
    case newerThanSupported(file: String, found: Int, supported: Int)
    /// The file is an older format that this build no longer reads.
    case olderThanSupported(file: String, found: Int, oldest: Int)
    /// No `schemaVersion`, broken JSON, or a field of the wrong shape.
    case unreadable(file: String, reason: String)
    /// Decodes, but breaks a rule (unknown exercise id, wrong week count…).
    case invalid(file: String, problems: [String])

    public var errorDescription: String? {
        switch self {
        case let .newerThanSupported(file, found, supported):
            "\(file) was made by a newer version of HealthCoach (format \(found)); this build reads up to format \(supported). Install the latest build."
        case let .olderThanSupported(file, found, oldest):
            "\(file) is in an old format (\(found)); this build reads format \(oldest) or later."
        case let .unreadable(file, reason):
            "\(file) couldn't be read: \(reason)"
        case let .invalid(file, problems):
            "\(file) has \(problems.count) problem\(problems.count == 1 ? "" : "s"): " + problems.joined(separator: "; ")
        }
    }
}

/// A format with a version number this build understands.
public protocol VersionedFormat: Decodable {
    static var currentSchemaVersion: Int { get }
    /// Oldest version still decoded (migrations live in the type's decoder).
    static var oldestSchemaVersion: Int { get }
}

extension VersionedFormat {
    public static var oldestSchemaVersion: Int { currentSchemaVersion }

    /// Checks the version first, so a newer file gets the "newer" message
    /// rather than a confusing decoding error.
    public static func decode(_ data: Data, file: String) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let header: SchemaHeader
        do {
            header = try decoder.decode(SchemaHeader.self, from: data)
        } catch {
            throw ContentError.unreadable(file: file, reason: "no schemaVersion (\(describe(error)))")
        }
        if header.schemaVersion > currentSchemaVersion {
            throw ContentError.newerThanSupported(file: file, found: header.schemaVersion, supported: currentSchemaVersion)
        }
        if header.schemaVersion < oldestSchemaVersion {
            throw ContentError.olderThanSupported(file: file, found: header.schemaVersion, oldest: oldestSchemaVersion)
        }
        do {
            return try decoder.decode(Self.self, from: data)
        } catch {
            throw ContentError.unreadable(file: file, reason: describe(error))
        }
    }
}

/// Just the version, read before the rest of a file.
struct SchemaHeader: Decodable {
    let schemaVersion: Int
}

/// Turns a DecodingError into one line naming the field, e.g.
/// "sessions.upper-a.blocks[0].items[1].sets: expected an array".
func describe(_ error: Error) -> String {
    func path(_ codingPath: [CodingKey]) -> String {
        var out = ""
        for key in codingPath {
            if let index = key.intValue {
                out += "[\(index)]"
            } else {
                out += out.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return out.isEmpty ? "top level" : out
    }
    guard let decoding = error as? DecodingError else { return String(describing: error) }
    switch decoding {
    case let .keyNotFound(key, context):
        return "\(path(context.codingPath + [key])): missing"
    case let .typeMismatch(type, context):
        return "\(path(context.codingPath)): expected \(type)"
    case let .valueNotFound(type, context):
        return "\(path(context.codingPath)): expected \(type), found null"
    case let .dataCorrupted(context):
        return "\(path(context.codingPath)): \(context.debugDescription)"
    @unknown default:
        return String(describing: error)
    }
}
