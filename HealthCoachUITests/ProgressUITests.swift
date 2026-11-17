import XCTest

/// Board M4-03 (re-planned): photo day every 2 weeks, and "Ask the coach now"
/// opening the share sheet.
final class ProgressUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openProgress(now: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", now, "-fixture", "week1-monday"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["progress.weight"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    func testPhotoDaySavesBothPosesAndIsThenDone() throws {
        // Monday 23 Nov 2026: the first day of week 1's 2-week block.
        let app = openProgress(now: "2026-11-23T07:00:00Z")
        let photoDay = app.buttons["progress.photoDay"]
        XCTAssertTrue(photoDay.waitForExistence(timeout: 5))
        photoDay.tap()
        XCTAssertTrue(app.buttons["photo.take.front"].waitForExistence(timeout: 5))
        app.buttons["photo.take.front"].tap()
        app.buttons["photo.take.side"].tap()
        // QA-23: shoot once the side button has settled on "Retake".
        let settled = NSPredicate(format: "label == 'Retake'")
        expectation(for: settled, evaluatedWith: app.buttons["photo.take.side"])
        waitForExpectations(timeout: 5)
        attach(app, "photo-day")
        app.buttons["photo.save"].tap()

        XCTAssertTrue(app.staticTexts["progress.nextPhotos"].waitForExistence(timeout: 5))
        XCTAssertFalse(photoDay.exists)
        attach(app, "progress-after-photos")
    }

    @MainActor
    func testAskTheCoachOpensTheShareSheet() throws {
        let app = openProgress(now: "2026-11-23T07:00:00Z")
        let ask = app.buttons["progress.askCoach"]
        // The section sits at the bottom of a lazy list: scroll until it's built.
        for _ in 0..<6 where !(ask.waitForExistence(timeout: 1) && ask.isHittable) { app.swipeUp() }
        XCTAssertTrue(ask.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["coach.import"].exists, "Import sits under Ask the coach now")
        ask.tap()
        // The system share sheet.
        let sheet = app.otherElements["ActivityListView"]
        let copy = app.buttons["Copy"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5) || copy.waitForExistence(timeout: 5))
        attach(app, "ask-the-coach-share")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
