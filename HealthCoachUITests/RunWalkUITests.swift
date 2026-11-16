import XCTest

/// Board M1-07: the week 1 run-walk (Tuesday 24 Nov 2026) starts from Today,
/// counts down, and pauses and resumes.
final class RunWalkUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWeekOneRunWalkPlays() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-24T06:20:00Z", "-fixture", "week1-monday"]
        app.launch()

        let start = app.buttons["today.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()

        let label = app.staticTexts["run.label"]
        let clock = app.staticTexts["run.clock"]
        XCTAssertTrue(label.waitForExistence(timeout: 10))
        XCTAssertTrue(clock.exists)

        // The clock counts down.
        let first = clock.label
        let moved = NSPredicate(format: "label != %@", first)
        expectation(for: moved, evaluatedWith: clock)
        waitForExpectations(timeout: 5)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "run-walk-week1"
        shot.lifetime = .keepAlways
        add(shot)

        let pause = app.buttons["run.pause"]
        XCTAssertEqual(pause.label, "Pause")
        pause.tap()
        XCTAssertEqual(pause.label, "Resume")
        let frozen = clock.label
        sleep(2)
        XCTAssertEqual(clock.label, frozen, "Clock moved while paused")
        pause.tap()
        XCTAssertEqual(pause.label, "Pause")
    }
}
