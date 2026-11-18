import Foundation

/// `Content/routes/<route>.json`: named run loops for a route (board N10).
/// The run-walk player names the loop closest to the session's distance.
public struct RunLoops: VersionedFormat, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let note: String?
    /// The programme's `route` id ("hyde-park").
    public let route: String
    public let start: Start
    public let loops: [Loop]

    public struct Start: Codable, Sendable, Equatable {
        public let name: String
        public let latitude: Double
        public let longitude: Double
    }

    public struct Loop: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let distanceKm: Double
        public let directions: [String]
    }

    /// The loop whose distance is closest to `km`; the shorter one on a tie.
    public func closest(toKm km: Double) -> Loop? {
        loops.min { a, b in
            let da = abs(a.distanceKm - km), db = abs(b.distanceKm - km)
            return da == db ? a.distanceKm < b.distanceKm : da < db
        }
    }

    public func problems() -> [String] {
        var out: [String] = []
        if loops.isEmpty { out.append("no loops") }
        var seen = Set<String>()
        for loop in loops {
            if !seen.insert(loop.id).inserted { out.append("loop \(loop.id) appears twice") }
            if !(0.5...15).contains(loop.distanceKm) { out.append("loop \(loop.id): distance \(loop.distanceKm) km out of range") }
            if loop.directions.isEmpty { out.append("loop \(loop.id): no directions") }
        }
        if !(-90...90).contains(start.latitude) || !(-180...180).contains(start.longitude) {
            out.append("start: coordinates out of range")
        }
        return out
    }
}
