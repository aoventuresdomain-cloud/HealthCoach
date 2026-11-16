import Foundation

/// Deterministic launch for simulator UI tests (QA test plan §3, board M1-01):
///
///     -uitest                      test mode: in-memory store, fake alarms, no animations
///     -now 2026-11-23T06:30:00Z    fixes the clock the app passes to CoachCore
///     -fixture week1-monday        loads App/Testing/Fixtures/fixture-week1-monday.json
///     -realAlarms                  with -uitest: real AlarmKit and alarm plan kept across launches (QA-2)
///
/// Debug builds only. Release builds ignore every flag, like the Spike tests screen.
struct LaunchOptions: Equatable {
    var isUITest = false
    var now: Date?
    var fixture: String?
    var realAlarms = false

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(isUITest: Bool = false, now: Date? = nil, fixture: String? = nil) {
        self.isUITest = isUITest
        self.now = now
        self.fixture = fixture
    }

    init(arguments: [String]) {
        #if DEBUG
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        isUITest = arguments.contains("-uitest")
        now = value(after: "-now").flatMap { try? Date.ISO8601FormatStyle().parse($0) }
        fixture = value(after: "-fixture")
        realAlarms = arguments.contains("-realAlarms")
        #endif
    }
}

/// The one clock the app hands to CoachCore. Fixed by `-now` in UI tests,
/// so a test of "Monday of week 1" is the same every run.
enum AppClock {
    static func now() -> Date {
        LaunchOptions.current.now ?? Date()
    }
}
