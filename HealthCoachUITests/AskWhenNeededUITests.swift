import XCTest

/// N4 · Ask when needed (ease budget §3): the shop question once, before the
/// first list; the office food question once, on the first office day.
/// Both have defaults, so skipping costs nothing.
final class AskWhenNeededUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Monday 23 November 2026, an office day in week2-hybrid (Mon, Tue, Thu).
    @MainActor
    private func openMeals() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-23T07:00:00Z", "-fixture", "week2-hybrid"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Meals"].tap()
        XCTAssertTrue(app.segmentedControls["meals.tabs"].waitForExistence(timeout: 5))
        return app
    }

    /// Ease A2: launch → first shopping list. Defaults: Shopping, Use these
    /// (2 taps, 15 s). Changed: Shopping, a shop, a slot, Use these (4 taps).
    @MainActor
    func testA2FirstShoppingListIsTwoTapsOrFourChanged() throws {
        for changed in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["-uitest", "-now", "2026-11-23T07:00:00Z", "-fixture", "week2-hybrid"]
            app.launch()
            XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
            let budget = EaseBudget(changed ? "first-list-changed" : "first-list", maxTaps: changed ? 4 : 2,
                                    maxSeconds: 15, app: app)
            budget.tap(app.tabBars.buttons["Shopping"], newScreen: true, system: true)
            let done = app.buttons["ask.shop.done"]
            XCTAssertTrue(done.waitForExistence(timeout: 5))
            if changed {
                budget.tap(app.buttons["ask.shop.option.ocado"])
                budget.tap(app.buttons["ask.shop.slot.saturday-10"])
            }
            budget.tap(done, newScreen: true)
            let header = app.staticTexts["shopping.header"]
            budget.finish(done: header)
            if changed { XCTAssertTrue(header.label.hasPrefix("Ocado · "), header.label) }
            app.terminate()
        }
    }

    @MainActor
    func testShopAnswerChangesTheListAndIsAskedOnce() throws {
        let app = openMeals()
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ask.shop"].waitForExistence(timeout: 5))
        app.buttons["ask.shop.option.ocado"].tap()
        XCTAssertTrue(app.buttons["ask.shop.option.ocado"].isSelected)
        XCTAssertFalse(app.buttons["ask.shop.option.waitrose"].isSelected)
        app.buttons["ask.shop.slot.saturday-10"].tap()
        attachShot(app, "ask-shop")
        app.buttons["ask.shop.done"].tap()

        // The list follows the answer at once.
        let header = app.staticTexts["shopping.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(header.label.hasPrefix("Ocado · "), header.label)
        let search = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'shopping.search.'")).firstMatch
        XCTAssertTrue(search.label.hasPrefix("Search Ocado for "), search.label)

        // Asked once: back to Shopping, no sheet.
        app.tabBars.buttons["Meals"].tap()
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ask.shop.done"].exists)
    }

    @MainActor
    func testSwipingTheShopQuestionAwayKeepsTheDefaults() throws {
        let app = openMeals()
        app.tabBars.buttons["Shopping"].tap()
        let sheet = app.descendants(matching: .any)["ask.shop"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        sheet.swipeDown(velocity: .fast)
        let header = app.staticTexts["shopping.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(header.label.hasPrefix("Waitrose · "), header.label)
        app.tabBars.buttons["Meals"].tap()
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ask.shop.done"].exists, "skipped counts as answered")
    }

    @MainActor
    func testOfficeLunchQuestionOnce() throws {
        let app = openMeals()
        app.segmentedControls["meals.tabs"].buttons["Lunch"].tap()
        XCTAssertTrue(app.buttons["lunch.suggestion"].waitForExistence(timeout: 5))
        let ask = app.descendants(matching: .any)["ask.lunch"]
        XCTAssertTrue(ask.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["ask.lunch.walk"].label.contains("Walk up to"))
        attachShot(app, "ask-lunch")
        let done = app.buttons["ask.lunch.done"]
        XCTAssertGreaterThanOrEqual(done.frame.height, 44)
        done.tap()
        XCTAssertTrue(ask.waitForNonExistence(timeout: 5), "answered, the line goes")
        XCTAssertTrue(app.buttons["lunch.suggestion"].exists)
    }

    @MainActor
    private func attachShot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
