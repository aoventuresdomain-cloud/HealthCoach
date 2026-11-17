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
                    // QA-5: background the app mid-rest so the Live Activity
                    // (lock screen / Dynamic Island) is in the shot.
                    XCUIDevice.shared.press(.home)
                    sleep(2)
                    let backgrounded = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                    backgrounded.name = "player-rest-backgrounded"
                    backgrounded.lifetime = .keepAlways
                    add(backgrounded)
                    // QA-5b: pull down the Notification Centre, which shows the
                    // Live Activity as the lock screen does.
                    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                    let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.005))
                    top.press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7)))
                    sleep(2)
                    let lockScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                    lockScreen.name = "player-rest-live-activity"
                    lockScreen.lifetime = .keepAlways
                    add(lockScreen)
                    // Back to the home screen, then the app.
                    XCUIDevice.shared.press(.home)
                    sleep(1)
                    app.activate()
                    XCTAssertTrue(next.waitForExistence(timeout: 10))
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
