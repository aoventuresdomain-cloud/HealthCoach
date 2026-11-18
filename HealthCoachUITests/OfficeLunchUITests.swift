import XCTest

/// Board N9a: the office lunch order is a row on Today's timeline on office
/// days (ease budget D8, 0 taps to see it), and the row opens the lunch card,
/// which carries N4's one-line question on the first office day (A3: 1 tap to
/// the suggestion, 3 to change the walk, skipping keeps the defaults).
/// Fixture week2-hybrid: office Monday, Tuesday and Thursday in the week of
/// 23 Nov 2026; nothing asked yet.
final class OfficeLunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(now: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", now, "-fixture", "week2-hybrid"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        return app
    }

    /// Tuesday 24 Nov, 10:00 in London: an office day.
    private let officeTuesday = "2026-11-24T10:00:00Z"

    /// D8 and A3 skipping: the order is on Today with no tap; one tap shows the suggestion.
    @MainActor
    func testOfficeDayShowsTheLunchRowAndOneTapOpensTheSuggestion() throws {
        let app = launch(now: officeTuesday)
        let row = app.buttons["today.timeline.lunch"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "office day: the lunch row is on Today")
        XCTAssertTrue(row.label.contains("12:30"), row.label)
        XCTAssertTrue(row.label.contains("Lunch"), row.label)

        let budget = EaseBudget("first-office-day", maxTaps: 1, maxSeconds: 10, app: app)
        budget.tap(row, newScreen: true)
        budget.finish(done: app.buttons["lunch.suggestion"])
        // First office day: the one-line question, with the content's defaults.
        XCTAssertTrue(app.descendants(matching: .any)["ask.lunch"].exists)
        XCTAssertTrue(app.buttons["ask.lunch.done"].exists)

        // Skipping: closing changes nothing, and the question waits for next time.
        app.buttons["lunch.close"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["ask.lunch"].waitForExistence(timeout: 5))
    }

    /// A3 changing: row, walk, choice. Picking the walk answers once, at once.
    @MainActor
    func testChangingTheWalkTakesThreeTapsAndIsAskedOnce() throws {
        let app = launch(now: officeTuesday)
        let row = app.buttons["today.timeline.lunch"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        let budget = EaseBudget("first-office-day-change", maxTaps: 3, maxSeconds: 10, app: app)
        budget.tap(row, newScreen: true)
        let walk = app.buttons["ask.lunch.walk"]
        XCTAssertTrue(walk.waitForExistence(timeout: 5))
        budget.tap(walk)
        let five = app.buttons["Walk up to 5 min"]
        XCTAssertTrue(five.waitForExistence(timeout: 5))
        // The menu's rows are drawn by iOS (42 pt high), not by the app: a system tap (E6 exempt).
        budget.tap(five, system: true)
        budget.finish(done: app.buttons["lunch.suggestion"])
        XCTAssertTrue(app.descendants(matching: .any)["ask.lunch"].waitForNonExistence(timeout: 5),
                      "answered: the question goes")

        // Kept: reopening the card doesn't ask again (a relaunch would reload the fixture's profile).
        app.buttons["lunch.close"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["lunch.suggestion"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["ask.lunch"].exists)
    }

    /// Office days only: Wednesday 25 Nov is a home day.
    @MainActor
    func testHomeDayHasNoLunchRow() throws {
        let app = launch(now: "2026-11-25T10:00:00Z")
        XCTAssertTrue(app.descendants(matching: .any)["today.timeline.windDown"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["today.timeline.lunch"].exists)
    }
}
