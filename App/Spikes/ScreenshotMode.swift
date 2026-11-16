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
    /// The Live Activity layouts (lock screen, Dynamic Island) drawn in-app,
    /// because the simulator can't be locked from the command line.
    case liveActivity = "live-activity"

    static var current: ScreenshotMode? {
        guard SpikeTests.isEnabled else { return nil }
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-screenshot"), flag + 1 < args.count else { return nil }
        return ScreenshotMode(rawValue: args[flag + 1])
    }
}
