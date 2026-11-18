import XCTest

/// N1 · Sunday check-in (ease budget §3, W1): two screens, defaults Good,
/// Fine, None; pain Yes shows six areas in place; Back keeps the answers;
/// done, the card goes and the office days are kept.
final class CheckInUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-22T18:00:00Z", "-fixture", "week2-hybrid-sunday"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    func testCheckInWithPainAndOfficeDays() throws {
        let app = launch()
        let card = app.buttons["today.checkIn"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("1 min"), card.label)
        card.tap()

        // Screen 1: defaults selected, weight hero and the week's line shown.
        let energy = app.segmentedControls["checkin.energy"]
        XCTAssertTrue(energy.waitForExistence(timeout: 5))
        XCTAssertTrue(energy.buttons["Good"].isSelected, "Energy defaults to Good")
        XCTAssertTrue(app.segmentedControls["checkin.sleep"].buttons["Fine"].isSelected, "Sleep defaults to Fine")
        let pain = app.segmentedControls["checkin.pain"]
        XCTAssertTrue(pain.buttons["None"].isSelected, "Pain defaults to None")
        XCTAssertTrue(app.descendants(matching: .any)["checkin.weight"].exists)
        XCTAssertTrue(app.staticTexts["checkin.weekLine"].exists)
        XCTAssertFalse(app.buttons["checkin.painArea.knee"].exists, "areas only after Yes")

        energy.buttons["Low"].tap()
        pain.buttons["Yes"].tap()
        for area in ["shoulder", "elbow", "wrist", "back", "knee", "other"] {
            let button = app.buttons["checkin.painArea.\(area)"]
            XCTAssertTrue(button.waitForExistence(timeout: 3), area)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, "\(area) is at least 44 pt tall")
        }
        app.buttons["checkin.painArea.knee"].tap()
        XCTAssertTrue(app.buttons["checkin.painArea.knee"].isSelected)
        attachShot(app, "checkin-week")

        // Screen 2, then Back: the answers are still there.
        app.buttons["checkin.next"].tap()
        let monday = app.buttons["sunday.day.monday"]
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(energy.waitForExistence(timeout: 5))
        XCTAssertTrue(energy.buttons["Low"].isSelected, "Back keeps the answers")
        XCTAssertTrue(app.buttons["checkin.painArea.knee"].isSelected)

        app.buttons["checkin.next"].tap()
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        if !monday.isSelected { monday.tap() }
        // Knee pain: next week's run-walk is a brisk walk, said once on screen 2 (Advisor c).
        XCTAssertTrue(app.descendants(matching: .any)["checkin.runWalkLine"].waitForExistence(timeout: 3))
        attachShot(app, "checkin-plan")
        app.buttons["checkin.done"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "the card goes once checked in")

        // The office days were kept.
        app.buttons["today.more"].tap()
        app.buttons["today.planWeekToolbar"].tap()
        XCTAssertTrue(app.buttons["sunday.day.monday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sunday.day.monday"].isSelected)
        app.buttons["sunday.cancel"].tap()
    }

    @MainActor
    func testLaterKeepsTheCard() throws {
        let app = launch()
        let card = app.buttons["today.checkIn"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let later = app.buttons["checkin.cancel"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5), "skipped, the card stays until Monday")
    }

    @MainActor
    private func attachShot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
