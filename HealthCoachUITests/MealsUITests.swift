import XCTest

/// Board M3-04: meals pre-ticked with day totals, a recipe opens, the top-up
/// list ticks off, and the lunch list suggests one order on office days.
final class MealsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openMeals() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-23T07:00:00Z", "-fixture", "week1-monday"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Meals"].tap()
        XCTAssertTrue(app.buttons["meals.tick.breakfast"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    func testMealsArePreTickedAndUntickingChangesTheTotal() throws {
        let app = openMeals()
        let totals = app.otherElements["meals.totals"].exists ? app.otherElements["meals.totals"] : app.staticTexts["meals.totals"]
        let before = totals.label
        attach(app, "meals-today")
        let breakfast = app.buttons["meals.tick.breakfast"]
        XCTAssertEqual(breakfast.label, "Eaten")
        breakfast.tap()
        XCTAssertEqual(app.buttons["meals.tick.breakfast"].label, "Not eaten")
        XCTAssertNotEqual(totals.label, before)

        app.buttons["meals.row.breakfast"].tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 5) || app.otherElements["recipe.view"].exists)
        attach(app, "recipe")
    }

    /// C4: one tap on Friday swaps the planned dinner for a social meal and
    /// counts it ("1 of 2"); a third that week is allowed and still counted.
    @MainActor
    func testSocialMealReplacesDinnerAndCounts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-27T07:00:00Z", "-fixture", "week1-monday"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Meals"].tap()

        let dinner = app.buttons["meals.row.dinner"]
        let social = app.buttons["meals.social"]
        let count = app.staticTexts["meals.socialCount"]
        func reveal(_ element: XCUIElement) {
            var swipes = 0
            while !element.isHittable, swipes < 4 { app.swipeUp(); swipes += 1 }
        }
        XCTAssertTrue(dinner.waitForExistence(timeout: 5))
        XCTAssertFalse(dinner.label.contains("Social meal"), dinner.label)
        reveal(social)
        XCTAssertEqual(count.label, "0 of 2 this week")
        func totals() -> String {
            // The header sits above the social row: scroll back up to it.
            var swipes = 0
            while !app.descendants(matching: .any)["meals.totals"].isHittable, swipes < 4 { app.swipeDown(); swipes += 1 }
            let other = app.otherElements["meals.totals"]
            return other.exists ? other.label : app.staticTexts["meals.totals"].label
        }
        // QA-R3-3: a normal day's header is unchanged.
        XCTAssertNotNil(totals().range(of: #"^[\d,]+ kcal · \d+ g protein$"#, options: .regularExpression), totals())

        reveal(social)
        social.tap()
        XCTAssertTrue(dinner.label.contains("Social meal"), "Friday's dinner wasn't replaced: \(dinner.label)")
        // The social meal is named, not counted (Advisor wording).
        XCTAssertNotNil(totals().range(of: #"^[\d,]+ kcal \+ social meal · \d+ g \+ social meal$"#,
                                       options: .regularExpression), totals())
        reveal(social)
        XCTAssertEqual(count.label, "1 of 2 this week")
        XCTAssertEqual(social.label, "Undo social meal")
        attach(app, "meals-social")

        // Saturday and Sunday too: the third is allowed and shows "3 of 2".
        for _ in 0..<2 {
            app.buttons["meals.nextDay"].tap()
            reveal(social)
            social.tap()
        }
        XCTAssertEqual(count.label, "3 of 2 this week")
        // And one tap undoes it.
        social.tap()
        XCTAssertEqual(count.label, "2 of 2 this week")
    }

    /// Ease W2 (Coach Engineer, #120): the shopping list is one tap from
    /// anywhere, 5 s. N4's one-off shop question is answered first, outside
    /// the budget (A2 measures it).
    @MainActor
    func testW2ShoppingListIsOneTapAway() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-23T09:00:00Z", "-fixture", "week1-monday"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
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

    @MainActor
    func testShoppingTicksAndLunchList() throws {
        let app = openMeals()
        // N9b (ease budget F2): Shopping is its own tab; Meals keeps Meals and Lunch.
        XCTAssertFalse(app.segmentedControls["meals.tabs"].buttons["Shopping"].exists)
        app.tabBars.buttons["Shopping"].tap()
        // N4: the first visit asks once, Waitrose and Sunday morning pre-selected.
        let useThese = app.buttons["ask.shop.done"]
        XCTAssertTrue(useThese.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ask.shop.option.waitrose"].isSelected)
        XCTAssertTrue(app.buttons["ask.shop.slot.sunday-10"].isSelected)
        useThese.tap()
        let tick = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shopping.tick.'")).firstMatch
        let found = tick.waitForExistence(timeout: 5)
        if !found { attach(app, "shopping-no-tick") }
        XCTAssertTrue(found)
        XCTAssertEqual(tick.label, "To buy")
        // Plan §4.4: every bought item links to the shop's search (not tapped: it leaves the app).
        let search = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'shopping.search.'")).firstMatch
        XCTAssertTrue(search.exists)
        XCTAssertTrue(search.label.hasPrefix("Search Waitrose for "))
        tick.tap()
        XCTAssertEqual(tick.label, "Got it")
        attach(app, "shopping")

        // UI-12: one header names the shop and counts what's left.
        XCTAssertTrue(app.staticTexts["shopping.header"].label.hasPrefix("Waitrose · "))

        app.tabBars.buttons["Meals"].tap()
        let lunchSegment = app.segmentedControls["meals.tabs"].buttons["Lunch"]
        XCTAssertTrue(lunchSegment.waitForExistence(timeout: 5))
        lunchSegment.tap()
        // UI-12: one suggestion (office day) or one line; the full list is behind "All N orders".
        let all = app.buttons["lunch.all"]
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["lunch.suggestion"].exists || app.staticTexts["lunch.noOffice"].exists)
        attach(app, "lunch")
        all.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'lunch.row.'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        attach(app, "lunch-orders")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
