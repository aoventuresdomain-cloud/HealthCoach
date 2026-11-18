import XCTest

/// The player's one-line explanations, seen on screen (gap plan §5):
/// N8, "Easing back in after N days off" on the first set after a break;
/// N10, the Hyde Park loop named as the run-walk sets off.
final class PlayerLinesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// N8 (D12): week 1 on track, last strength session Thu 26 Nov, then
    /// nothing until Mon 7 Dec: 11 days off, the 90% band. Start costs one
    /// tap and the player says why the loads are lighter; nothing is asked.
    @MainActor
    func testEasingBackInIsExplainedOnTheFirstSet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-12-07T07:00:00Z", "-fixture", "week1-on-track"]
        app.launch()

        let start = app.buttons["today.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()

        let easing = app.staticTexts["player.easing"]
        let shown = easing.waitForExistence(timeout: 10)
        attach(app, "player-easing")
        XCTAssertTrue(shown, "no easing line on the first set")
        XCTAssertTrue(easing.label.hasPrefix("Easing back in after "), easing.label)
        XCTAssertTrue(easing.label.hasSuffix(" days off."), easing.label)
        // No question on the way in (D12: 0 extra taps).
        XCTAssertEqual(app.alerts.count, 0)
    }

    /// N10: Tuesday's week 1 run-walk names its loop on the first segment.
    @MainActor
    func testRunWalkNamesItsLoopAsItSetsOff() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-24T06:20:00Z", "-fixture", "week1-monday"]
        app.launch()

        let start = app.buttons["today.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()

        let loop = app.staticTexts["run.loop"]
        let shown = loop.waitForExistence(timeout: 10)
        attach(app, "run-walk-loop")
        XCTAssertTrue(shown, "no loop line on the first segment")
        // "Serpentine loop, about 3.5 km"
        XCTAssertTrue(loop.label.contains(", about "), loop.label)
        XCTAssertTrue(loop.label.hasSuffix(" km"), loop.label)
    }
}
