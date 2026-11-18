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

        // The 20 s budget is the person's time, so it's measured with the ease-budget
        // model (docs/qa/ease-budget-method.md), not simulator wall time: on slow CI
        // runners, XCUITest queries and the screenshot took 20-30 s for these 5 taps.
        // The helper counts the real taps, so an extra step still fails the budget.
        let budget = EaseBudget("sunday-prompt", maxTaps: 5, maxSeconds: 20, app: app)
        budget.tap(card, newScreen: true)
        let monday = app.buttons["sunday.day.monday"]
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "sunday-prompt"
        shot.lifetime = .keepAlways
        add(shot)
        budget.tap(monday)
        budget.tap(app.buttons["sunday.day.tuesday"])
        budget.tap(app.buttons["sunday.day.thursday"])
        budget.tap(app.buttons["sunday.done"])
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "the card stays until next week is answered")
        budget.finish(done: app.staticTexts["today.title"])

        // Reopening shows what was saved.
        openMenuItem(app, "today.planWeekToolbar")
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
        openMenuItem(app, "today.planWeekToolbar")
        let times = app.buttons["sunday.times"]
        XCTAssertTrue(times.waitForExistence(timeout: 5))
        times.tap()
        let early = app.switches["sunday.early.monday"]
        XCTAssertTrue(early.waitForExistence(timeout: 5))
        // Tap the switch itself at the trailing edge; the label doesn't toggle it reliably.
        early.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertEqual(early.value as? String, "1")
        app.buttons["sunday.done"].tap()

        openMenuItem(app, "today.planWeekToolbar")
        XCTAssertTrue(app.switches["sunday.early.monday"].waitForExistence(timeout: 5),
                      "times stay open when any are set")
        XCTAssertEqual(app.switches["sunday.early.monday"].value as? String, "1")
    }

    /// UI-12: Plan the week lives in Today's ⋯ menu.
    @MainActor
    private func openMenuItem(_ app: XCUIApplication, _ id: String) {
        let more = app.buttons["today.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let item = app.buttons[id]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
    }
}
