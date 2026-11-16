import XCTest

/// Board M1-06: a full Phase 1 session completes touching only "Next" and
/// "Done". Monday of week 1 is Upper A (phase-1.json), started from Today.
final class WorkoutPlayerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testUpperACompletesWithOnlyNextAndDone() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-23T06:20:00Z", "-fixture", "week1-monday"]
        app.launch()

        let start = app.buttons["today.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()

        let next = app.buttons["player.next"]
        let done = app.buttons["player.done"]
        let finish = app.buttons["player.finish"]
        let restClock = app.descendants(matching: .any)["player.restClock"]
        XCTAssertTrue(app.buttons["player.end"].waitForExistence(timeout: 10))

        var taps = 0
        var restShot = false
        while !finish.exists {
            XCTAssertLessThan(taps, 200, "Session did not reach the done screen")
            if done.exists, done.isHittable {
                done.tap()
                taps += 1
            } else if next.exists, next.isHittable {
                if !restShot, restClock.exists {
                    attach(app, "player-rest")
                    restShot = true
                }
                next.tap()
                taps += 1
            } else {
                _ = finish.waitForExistence(timeout: 1)
            }
        }

        XCTAssertTrue(restShot, "Expected at least one rest between sets")
        XCTAssertTrue(app.staticTexts["player.doneTitle"].waitForExistence(timeout: 5))
        attach(app, "player-done")
        finish.tap()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 10))
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
