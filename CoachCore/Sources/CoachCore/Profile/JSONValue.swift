import Foundation

/// A plain JSON tree, for migrating and merging stored records without
/// JSONSerialization (whose number and bool handling differs on Linux).
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case let .bool(v): try c.encode(v)
        case let .number(v): try c.encode(v)
        case let .string(v): try c.encode(v)
        case let .array(v): try c.encode(v)
        case let .object(v): try c.encode(v)
        }
    }

    /// `other` laid over `self`: objects merge key by key, anything else is replaced.
    public func merging(_ other: JSONValue) -> JSONValue {
        guard case var .object(base) = self, case let .object(over) = other else { return other }
        for (key, value) in over {
            base[key] = base[key].map { $0.merging(value) } ?? value
        }
        return .object(base)
    }

    public subscript(key: String) -> JSONValue? {
        get {
            guard case let .object(o) = self else { return nil }
            return o[key]
        }
        set {
            guard case var .object(o) = self else { return }
            o[key] = newValue
            self = .object(o)
        }
    }
}
