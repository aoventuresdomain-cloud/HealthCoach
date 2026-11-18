import XCTest

/// Board N9 (QA-R4): the gap plan's daily jobs measured against
/// docs/design/ease-budget.md §2 through `EaseBudget`, like the Sunday prompt
/// test. D2 start a session, D6 change a meal, W2 find the shopping list,
/// F1b photo day from Progress. (W1 is SundayPromptUITests and
/// NotificationRouteUITests; F1 from the notification follows once the
/// photo-day route opens the camera screen.)
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
        budget.finish(done: app.buttons["player.done"])
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
        budget.finish(done: app.buttons["player.done"])
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

    // MARK: W2 · Find the shopping list (1 tap, 5 s)

    /// Until N9b, Shopping is a segment inside Meals: one tap over the
    /// design's Shopping tab, allowed and noted, like GroceryUITests.
    @MainActor
    func testW2ShoppingListIsOneTapAway() throws {
        let app = launch(now: "2026-11-23T09:00:00Z")
        let tab = app.tabBars.buttons["Shopping"].exists
        let extra = tab ? 0 : 1
        // N4's one-off shop question is its own row (A2): answer it outside the budget.
        openShopping(app, tab: tab, budget: nil)
        let ask = app.buttons["ask.shop.done"]
        if ask.waitForExistence(timeout: 2) { ask.tap() }
        XCTAssertTrue(app.staticTexts["shopping.header"].waitForExistence(timeout: 5))
        app.terminate()

        let again = launch(now: "2026-11-23T09:00:00Z")
        let budget = EaseBudget("shopping-list", maxTaps: 1 + extra, maxSeconds: 5, app: again)
        openShopping(again, tab: tab, budget: budget)
        budget.finish(done: again.staticTexts["shopping.header"],
                      note: extra == 0 ? nil : "+1 tap: Shopping segment until N9b")
    }

    @MainActor
    private func openShopping(_ app: XCUIApplication, tab: Bool, budget: EaseBudget?) {
        let steps: [XCUIElement] = tab
            ? [app.tabBars.buttons["Shopping"]]
            : [app.tabBars.buttons["Meals"], app.segmentedControls["meals.tabs"].buttons["Shopping"]]
        for (index, step) in steps.enumerated() {
            XCTAssertTrue(step.waitForExistence(timeout: 5))
            if let budget {
                // Tab bar and segmented control are system chrome (E6 `system`).
                budget.tap(step, newScreen: index == 0, system: true)
            } else {
                step.tap()
            }
        }
    }

    // MARK: F1b · Photo day from Progress (5 taps, 60 s)

    /// Progress, the photo-day card, front, side, Save. UI tests draw a
    /// stand-in for each photo, so there is no self-timer to add.
    @MainActor
    func testF1bPhotoDayFromProgressIsFiveTaps() throws {
        let app = launch(now: "2026-11-23T07:00:00Z")
        let budget = EaseBudget("photo-day-from-progress", maxTaps: 5, maxSeconds: 60, app: app)
        budget.tap(app.tabBars.buttons["Progress"], newScreen: true, system: true)
        let card = app.buttons["progress.photoDay"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        budget.tap(card, newScreen: true)
        let front = app.buttons["photo.take.front"], side = app.buttons["photo.take.side"]
        XCTAssertTrue(front.waitForExistence(timeout: 5))
        budget.tap(front)
        budget.tap(side)
        // QA-23: the side button settles on "Retake" before Save.
        expectation(for: NSPredicate(format: "label == 'Retake'"), evaluatedWith: side)
        waitForExpectations(timeout: 5)
        budget.tap(app.buttons["photo.save"])
        budget.finish(done: app.descendants(matching: .any)["progress.nextPhotos"])
    }
}
