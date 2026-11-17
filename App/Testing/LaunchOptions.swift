import CoachCore
import Foundation

/// Deterministic launch for simulator UI tests (QA test plan §3, board M1-01):
///
///     -uitest                      test mode: in-memory store, fake alarms, no animations
///     -now 2026-11-23T06:30:00Z    fixes the clock the app passes to CoachCore
///     -fixture week1-monday        loads App/Testing/Fixtures/fixture-week1-monday.json
///     -fixture week1-on-track      week 1 with Mon, Tue and Thu logged (a normal rest Friday)
///     -fixture week2-hybrid        Gate 1 §A: week 2 from 23 Nov, office Mon/Tue/Thu, early Tue 08:00, late Thu 19:00
///     -realAlarms                  with -uitest: real AlarmKit and alarm plan kept across launches (QA-2)
///     -denyAlarms                  with -uitest: the fake alarms report no permission (QA-1 warning)
///     -spikeAlarms                 the spike screen keeps the alarms even with a planned profile (QA-2)
///     -weather rain|dry|offline    fake forecast for the weather swap (M2-03); UI tests are offline without it
///     -clipboard <text>            what "Import Claude's reply" reads instead of the clipboard (M4-02, QA A17)
///     -clipboardBase64 <base64>    the same, base64 UTF-8, for multi-line text (a raw argument with
///                                  newlines and quotes didn't reach the app intact in A17's UI test)
///     -keepCoachBlocks             with -uitest: imported blocks survive the relaunch (A17 "next day" check)
///
/// Debug builds only. Release builds ignore every flag, like the Spike tests screen.
struct LaunchOptions: Equatable {
    var isUITest = false
    var now: Date?
    var fixture: String?
    var realAlarms = false
    var spikeAlarms = false
    var weather: String?
    var denyAlarms = false
    var clipboard: String?
    var keepCoachBlocks = false

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
        spikeAlarms = arguments.contains("-spikeAlarms")
        weather = value(after: "-weather")
        denyAlarms = arguments.contains("-denyAlarms")
        clipboard = value(after: "-clipboardBase64")
            .flatMap { Data(base64Encoded: $0) }
            .flatMap { String(data: $0, encoding: .utf8) }
            ?? value(after: "-clipboard")
        keepCoachBlocks = arguments.contains("-keepCoachBlocks")
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
