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

    @MainActor
    func testShoppingTicksAndLunchList() throws {
        let app = openMeals()
        app.segmentedControls["meals.tabs"].buttons["Shopping"].tap()
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

        app.segmentedControls["meals.tabs"].buttons["Lunch"].tap()
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
