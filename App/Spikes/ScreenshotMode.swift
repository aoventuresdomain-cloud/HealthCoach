import CoachCore
import Foundation

/// Launch arguments that open the app straight onto a spike state, so CI
/// (board M0-12) can take simulator screenshots with no taps:
///
///     xcrun simctl launch booted com.aoventures.healthcoach -screenshot <mode>
///
/// Ignored unless the Spike tests screen is enabled. Removed with it before Gate 1.
enum ScreenshotMode: String {
    /// Spike tests screen, nothing run.
    case spikes
    /// Spike tests screen with the rest timer running (real Live Activity started).
    case spikesTimer = "spikes-timer"
    /// Starts the rest timer, then cancels it after 5 s (Live Activity should vanish).
    case spikesTimerCancel = "spikes-timer-cancel"
    /// Spike tests screen that taps "Set test alarms" by itself. In a fresh
    /// simulator AlarmKit may show its permission prompt first; that is a finding.
    case spikesSetAlarms = "spikes-set-alarms"
    /// The Live Activity layouts (lock screen, Dynamic Island) drawn in-app,
    /// because the simulator can't be locked from the command line.
    case liveActivity = "live-activity"

    /// Optional `-restSeconds <n>` to shorten the test rest, so a screenshot run
    /// can wait for the timer to finish without spending 90 s of CI time.
    static var restSeconds: Int? {
        guard current != nil else { return nil }
        return value(after: "-restSeconds").flatMap(Int.init)
    }

    static var current: ScreenshotMode? {
        guard SpikeTests.isEnabled else { return nil }
        return value(after: "-screenshot").flatMap(ScreenshotMode.init(rawValue:))
    }

    private static func value(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
}
