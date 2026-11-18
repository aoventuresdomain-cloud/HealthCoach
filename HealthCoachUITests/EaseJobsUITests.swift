import XCTest

/// Board N9 (QA-R4): the gap plan's daily jobs measured against
/// docs/design/ease-budget.md §2 through `EaseBudget`, like the Sunday prompt
/// test: D2 start a session, D6 change a meal. W1 is SundayPromptUITests and
/// NotificationRouteUITests; W2 lands with N9b's Shopping tab and F1/F1b with
/// N7's photo-day screen, each with the fix that brings it inside budget.
final class EaseJobsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Monday 23 Nov 2026, 06:20 in London: week 1, Upper A due, photo day due.
    @MainActor
    private func launch(now: String = "2026-11-23T06:20:00Z") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", now, "-fixture", "week1-monday"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        return app
    }

    // MARK: D2 · Start today's session (1 / 2 taps, 10 s)

    @MainActor
    func testD2StartTodaysSessionIsOneTap() throws {
        let app = launch()
        let budget = EaseBudget("start-session", maxTaps: 1, maxSeconds: 10, app: app)
        budget.tap(app.buttons["today.start"], newScreen: true)
        budget.finish(done: playerOpen(app))
    }

    /// Change path: "Still sore" first. The segmented control is system chrome (E6 `system`).
    @MainActor
    func testD2StartWhenStillSoreIsTwoTaps() throws {
        let app = launch()
        let budget = EaseBudget("start-session-sore", maxTaps: 2, maxSeconds: 10, app: app)
        let recovery = app.segmentedControls["today.recovery"]
        XCTAssertTrue(recovery.waitForExistence(timeout: 5))
        budget.tap(recovery.buttons["Still sore"], system: true)
        budget.tap(app.buttons["today.start"], newScreen: true)
        budget.finish(done: playerOpen(app))
    }

    /// D2's done state: the session has started, so the player is on its first
    /// screen. That is the warm-up (`player.next`), not set 1: the design's
    /// `player.done` would take a second tap through the warm-up. `player.end`
    /// is on every player screen.
    @MainActor
    private func playerOpen(_ app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(app.buttons["player.next"].waitForExistence(timeout: 10), "the player opens on the warm-up")
        return app.buttons["player.end"]
    }

    // MARK: D6 · Change a meal (2 taps, 10 s)

    /// Skipped breakfast: Meals, then untick. Unticking asks nothing.
    @MainActor
    func testD6UntickingAMealIsTwoTapsAndAsksNothing() throws {
        let app = launch(now: "2026-11-23T09:00:00Z")
        let budget = EaseBudget("change-meal", maxTaps: 2, maxSeconds: 10, app: app)
        budget.tap(app.tabBars.buttons["Meals"], newScreen: true, system: true)
        let tick = app.buttons["meals.tick.breakfast"]
        XCTAssertTrue(tick.waitForExistence(timeout: 5))
        XCTAssertEqual(tick.label, "Eaten", "planned meals start ticked")
        budget.tap(tick)
        let notEaten = app.buttons.matching(NSPredicate(format: "identifier == 'meals.tick.breakfast' AND label == 'Not eaten'"))
            .firstMatch
        budget.finish(done: notEaten)
        XCTAssertEqual(app.alerts.count, 0, "unticking triggers no prompt")
    }
}
