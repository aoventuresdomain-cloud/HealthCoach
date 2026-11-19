import XCTest

/// Board N9 (QA-R4): the gap plan's daily jobs measured against
/// docs/design/ease-budget.md §2 through `EaseBudget`, like the Sunday prompt
/// test: D2 start a session, D6 change a meal. W1 is SundayPromptUITests and
/// NotificationRouteUITests; W2 lands with N9b's Shopping tab. F1 (from the
/// photo-day reminder) and F1b (from Progress) run on N7's camera.
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

    // MARK: F1b · Photo day from Progress (5 taps, 60 s)

    /// Progress, the photo-day card, front, side, Save. N7's camera runs a 3 s
    /// self-timer per pose, so each step waits for its screen.
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
        XCTAssertTrue(side.waitForExistence(timeout: 8), "the side pose didn't follow the front")
        budget.tap(side, newScreen: true)
        let save = app.buttons["photo.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 8), "no review screen after both poses")
        budget.tap(save, newScreen: true)
        budget.finish(done: app.descendants(matching: .any)["progress.nextPhotos"])
    }

    // MARK: W2 · Find the shopping list (1 tap, 5 s)

    /// Ease W2: the shopping list is one tap from
    /// anywhere, 5 s. N4's one-off shop question is answered first, outside
    /// the budget (A2 measures it).
    @MainActor
    func testW2ShoppingListIsOneTapAway() throws {
        let app = launch(now: "2026-11-23T09:00:00Z")
        app.tabBars.buttons["Shopping"].tap()
        let ask = app.buttons["ask.shop.done"]
        if ask.waitForExistence(timeout: 3) { ask.tap() }
        XCTAssertTrue(app.staticTexts["shopping.header"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 5))

        let budget = EaseBudget("shopping-list", maxTaps: 1, maxSeconds: 5, app: app)
        budget.tap(app.tabBars.buttons["Shopping"], newScreen: true, system: true)
        budget.finish(done: app.staticTexts["shopping.header"])
    }

    // MARK: F1 · Photo day from the notification (4 taps, 60 s)

    /// The photo-day reminder opens the camera (N7, NotificationRoute); then
    /// front, side, Save. Waist is off by default, so it adds nothing. The two
    /// 3 s self-timers sit outside the model (ease budget F1): "+6 s timer".
    @MainActor
    func testF1PhotoDayFromTheNotificationIsFourTaps() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-23T07:00:00Z", "-fixture", "week1-monday",
                               "-openFrom", "notification:photoDay"]
        app.launch()
        let budget = EaseBudget("photo-day", maxTaps: 4, maxSeconds: 60, app: app)
        budget.notificationTap()
        let front = app.buttons["photo.take.front"], side = app.buttons["photo.take.side"]
        XCTAssertTrue(front.waitForExistence(timeout: 15), "the reminder opens the photo-day camera")
        budget.tap(front)
        XCTAssertTrue(side.waitForExistence(timeout: 8), "the side pose didn't follow the front")
        budget.tap(side, newScreen: true)
        let save = app.buttons["photo.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 8), "no review screen after both poses")
        budget.tap(save, newScreen: true)
        budget.finish(done: app.descendants(matching: .any)["progress.nextPhotos"], note: "+6 s timer")
    }
}
