import XCTest

/// C2: one line on Today when the coach is needed (stall flag, checkpoint due
/// or dumbbell limit). Tapping it opens Progress with "Ask the coach now" in view.
final class CoachLineUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(now: String, fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", now, "-fixture", fixture]
        app.launch()
        return app
    }

    /// Weight flat at 82 kg from three weeks before the start (16 Nov) to
    /// Sunday of week 3: the week 3 and 4 checks both see it, so Monday of
    /// week 4 is a two-week stall.
    @MainActor
    func testFlatWeightShowsTheLineAndOpensAsk() throws {
        let app = launch(now: "2026-12-07T09:00:00Z", fixture: "week4-flat-weight")
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        let line = app.buttons["today.coachLine"]
        XCTAssertTrue(line.waitForExistence(timeout: 10), "no coach line on a flat-weight week")
        XCTAssertEqual(line.label, "Your weight has been flat for 2 weeks. Ask the coach.")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "today-coach-line"
        shot.lifetime = .keepAlways
        add(shot)

        line.tap()
        let ask = app.buttons["progress.askCoach"]
        XCTAssertTrue(ask.waitForExistence(timeout: 5), "Progress didn't open on Ask the coach now")
        // In view, clear of the floating tab bar, after the scroll settles.
        let tabBar = app.tabBars.firstMatch
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline, !(ask.isHittable && (!tabBar.exists || ask.frame.maxY <= tabBar.frame.minY)) {
            _ = ask.waitForNonExistence(timeout: 0.25)
        }
        XCTAssertTrue(ask.isHittable, "Ask the coach now is off screen")
        if tabBar.exists {
            XCTAssertLessThanOrEqual(ask.frame.maxY, tabBar.frame.minY, "Ask \(ask.frame) sits behind the tab bar")
        }
        let progressShot = XCTAttachment(screenshot: app.screenshot())
        progressShot.name = "progress-ask-from-today"
        progressShot.lifetime = .keepAlways
        add(progressShot)
    }

    /// A normal first week: nothing to ask, so no line.
    @MainActor
    func testNormalWeekShowsNoLine() throws {
        let app = launch(now: "2026-11-23T06:20:00Z", fixture: "week1-monday")
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        // Wait for the Health read, after which a line would have appeared.
        let status = app.staticTexts["debug.launch"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "NOT (label CONTAINS 'weight=pending')"), evaluatedWith: status)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.buttons["today.coachLine"].waitForExistence(timeout: 2), "coach line on a normal week")
    }
}
