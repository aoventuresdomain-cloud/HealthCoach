import XCTest

/// N3: ⋯ → Settings lists every module with its current value, a module
/// edits in a standard form, changes save as they are made (no Save), and
/// the footer says they start tomorrow.
final class PreferencesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private let modules = ["you", "goal", "hurts", "sleep", "work", "office", "fixed",
                           "kit", "longest", "cues", "checkIn", "food"]

    @MainActor
    private func openPreferences(_ app: XCUIApplication) {
        let more = app.buttons["today.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 15))
        more.tap()
        let settings = app.buttons["today.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.buttons["prefs.done"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func module(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let row = app.descendants(matching: .any)["prefs.module.\(name)"]
        var swipes = 0
        while !(row.exists && row.isHittable), swipes < 6 { app.swipeUp(); swipes += 1 }
        return row
    }

    @MainActor
    func testEveryModuleShowsItsValueAndADislikeSavesFromTomorrow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-23T06:20:00Z", "-fixture", "week1-monday"]
        app.launch()
        openPreferences(app)

        for name in modules {
            let row = module(app, name)
            XCTAssertTrue(row.exists, "no module \(name)")
            XCTAssertFalse(row.label.isEmpty, "no label on \(name)")
        }
        XCTAssertTrue(app.staticTexts["prefs.fromTomorrow"].exists, "no 'Changes start tomorrow.'")
        XCTAssertTrue(module(app, "food").label.contains("None"), module(app, "food").label)

        module(app, "food").tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("mushrooms")
        let addButton = app.buttons["prefs.dislikeAdd"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "preferences-foods"
        shot.lifetime = .keepAlways
        add(shot)
        app.navigationBars.buttons.element(boundBy: 0).tap() // back to the list
        XCTAssertTrue(module(app, "food").label.contains("mushrooms"), module(app, "food").label)
        attachShot(app, "preferences")
        app.buttons["prefs.done"].tap()

        // Saved as made: reopened, the edit waiting for tomorrow is what shows.
        openPreferences(app)
        XCTAssertTrue(module(app, "food").label.contains("mushrooms"), module(app, "food").label)
    }

    @MainActor
    private func attachShot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
