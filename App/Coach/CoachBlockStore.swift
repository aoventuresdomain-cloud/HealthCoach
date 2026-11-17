import CoachCore
import Foundation

/// Accepted Claude blocks (board M4-02). Stored like the Sunday answers, as
/// CoachCore's own JSON in UserDefaults, so the format never needs a SwiftData
/// migration. The rules engine replays these; nothing else is stored.
@MainActor
final class CoachBlockStore {
    private let defaults: UserDefaults
    private let key = "coach.blocks.v1"

    /// UI tests use their own suite, emptied at launch, so runs never leak into each other.
    static let uiTestSuite = "healthcoach.uitest.coach"

    init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.defaults = defaults
        } else if LaunchOptions.current.isUITest, let suite = UserDefaults(suiteName: Self.uiTestSuite) {
            self.defaults = suite
        } else {
            self.defaults = .standard
        }
    }

    /// Empties the UI-test suite. Called once at launch in `-uitest` mode.
    static func resetForUITest() {
        UserDefaults(suiteName: uiTestSuite)?.removePersistentDomain(forName: uiTestSuite)
    }

    /// Oldest first. An unreadable or newer-format list reads as empty, so the
    /// plan falls back to the rules engine alone rather than failing.
    var all: [CoachBlock] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? CoachBlock.stored(from: data)) ?? []
    }

    func replace(with blocks: [CoachBlock]) throws {
        defaults.set(try CoachBlock.storedData(blocks), forKey: key)
    }
}
