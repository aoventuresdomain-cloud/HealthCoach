import XCTest

/// Board M2-05: the Sunday prompt takes under 20 seconds of taps, and the
/// answers are kept (reopening shows them).
final class SundayPromptUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Sunday 22 November 2026, 17:00 in London; week 1 starts the next day.
    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-22T17:00:00Z", "-fixture", "week1-monday"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    func testSundayPromptTakesUnderTwentySeconds() throws {
        let app = launch()
        let card = app.buttons["today.planWeek"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        let started = Date()
        card.tap()
        let monday = app.buttons["sunday.day.monday"]
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "sunday-prompt"
        shot.lifetime = .keepAlways
        add(shot)
        monday.tap()
        app.buttons["sunday.day.tuesday"].tap()
        app.buttons["sunday.day.thursday"].tap()
        app.buttons["sunday.done"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "the card stays until next week is answered")
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertLessThan(elapsed, 20, "Sunday prompt took \(elapsed) s")

        // Reopening shows what was saved.
        app.buttons["today.planWeekToolbar"].tap()
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        XCTAssertTrue(monday.isSelected)
        XCTAssertTrue(app.buttons["sunday.day.tuesday"].isSelected)
        XCTAssertFalse(app.buttons["sunday.day.wednesday"].isSelected)
        XCTAssertTrue(app.buttons["sunday.day.thursday"].isSelected)
        XCTAssertFalse(app.buttons["sunday.day.friday"].isSelected)
        app.buttons["sunday.cancel"].tap()
    }

    @MainActor
    func testEarlyStartIsKept() throws {
        let app = launch()
        app.buttons["today.planWeekToolbar"].tap()
        let times = app.buttons["sunday.times"]
        XCTAssertTrue(times.waitForExistence(timeout: 5))
        times.tap()
        let early = app.switches["sunday.early.monday"]
        XCTAssertTrue(early.waitForExistence(timeout: 5))
        // Tap the switch itself at the trailing edge; the label doesn't toggle it reliably.
        early.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertEqual(early.value as? String, "1")
        app.buttons["sunday.done"].tap()

        app.buttons["today.planWeekToolbar"].tap()
        XCTAssertTrue(app.switches["sunday.early.monday"].waitForExistence(timeout: 5),
                      "times stay open when any are set")
        XCTAssertEqual(app.switches["sunday.early.monday"].value as? String, "1")
    }
}
