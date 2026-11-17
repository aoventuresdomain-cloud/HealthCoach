import XCTest

/// Board M2-06: "Tomorrow changed" re-plans tomorrow only. Monday 23 Nov 2026,
/// week 1; with no Sunday answers every day is a home day, so tomorrow
/// (Tuesday) has no "Leave for the office" row until it becomes an office day.
/// M0-11b: the spike wrench never shows without -spikeAlarms.
final class TomorrowChangedUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTomorrowChangedUpdatesTomorrowAndLeavesTodayAlone() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-23T06:20:00Z", "-fixture", "week1-monday"]
        app.launch()
        let title = app.staticTexts["today.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["home.spikeTests"].exists, "M0-11b: no wrench in review launches")

        let todayTitle = title.label
        let todayWake = app.descendants(matching: .any)["today.timeline.wake"]
        XCTAssertTrue(todayWake.waitForExistence(timeout: 5))
        let todayWakeLabel = todayWake.label
        XCTAssertFalse(app.descendants(matching: .any)["today.timeline.leave"].exists)

        let changed = app.buttons["today.tomorrowChanged"]
        XCTAssertTrue(changed.waitForExistence(timeout: 5))
        changed.tap()
        let office = app.buttons["tomorrow.office"]
        XCTAssertTrue(office.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tomorrow.home"].isSelected, "pre-filled from the week: home")
        attach(app, "tomorrow-changed")
        office.tap()
        XCTAssertTrue(office.isSelected)
        app.buttons["tomorrow.done"].tap()

        // Tomorrow is shown re-planned as an office day.
        let back = app.buttons["today.backToToday"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["today.timeline.leave"].waitForExistence(timeout: 5),
                      "tomorrow is now an office day")
        attach(app, "tomorrow-replanned")

        // Today is unchanged.
        back.tap()
        XCTAssertTrue(app.buttons["today.start"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["today.title"].label, todayTitle)
        XCTAssertEqual(app.descendants(matching: .any)["today.timeline.wake"].label, todayWakeLabel)
        XCTAssertFalse(app.descendants(matching: .any)["today.timeline.leave"].exists)

        // Reopening shows tomorrow's saved answer.
        app.buttons["today.tomorrowChanged"].tap()
        XCTAssertTrue(app.buttons["tomorrow.office"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tomorrow.office"].isSelected)
        app.buttons["tomorrow.cancel"].tap()
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
