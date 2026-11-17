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
                    // QA-25: a fresh simulator asks "Allow Live Activities from
                    // HealthCoach?" the first time; until it is allowed the island
                    // stays empty. Accept it so the shots show the real activity.
                    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                    allowLiveActivities(springboard)
                    let backgrounded = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                    backgrounded.name = "player-rest-backgrounded"
                    backgrounded.lifetime = .keepAlways
                    add(backgrounded)
                    // QA-5b: pull down the Notification Centre, which shows the
                    // Live Activity as the lock screen does.
                    let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.005))
                    top.press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7)))
                    sleep(2)
                    allowLiveActivities(springboard)
                    // QA-19: the rest activity itself, not a leftover run-walk one.
                    let restTitle = springboard.staticTexts["Rest"]
                    XCTAssertTrue(restTitle.waitForExistence(timeout: 5), "no rest Live Activity in the Notification Centre")
                    let leftoverRun = springboard.staticTexts.matching(
                        NSPredicate(format: "label CONTAINS[c] 'run-walk · Week'"))
                    XCTAssertEqual(leftoverRun.count, 0, "a run-walk Live Activity is still showing")
                    // UI-11: the next set is the 10 kg bench press, so the lock screen says what to dial.
                    let dialTo = springboard.descendants(matching: .any)
                        .matching(NSPredicate(format: "label BEGINSWITH[c] 'Dial to'")).firstMatch
                    XCTAssertTrue(dialTo.waitForExistence(timeout: 3), "no DIAL TO weight on the rest Live Activity")
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

    /// Taps "Allow" on the system's first-time Live Activities prompt if it is
    /// showing. Does nothing when it has already been answered.
    @MainActor
    private func allowLiveActivities(_ springboard: XCUIApplication) {
        let allow = springboard.buttons.matching(NSPredicate(format: "label ==[c] 'Allow'")).firstMatch
        if allow.waitForExistence(timeout: 3), allow.isHittable {
            allow.tap()
            sleep(2)
        }
    }
}
