import XCTest

/// Board M1-04: onboarding confirms in well under 5 minutes of taps with every
/// default pre-filled, and the result is stored in the profile record.
final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDefaultsArePreFilledAndTwoTapsConfirm() throws {
        let started = Date()
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-16T09:00:00Z", "-fixture", "new-install"]
        app.launch()

        XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 15))
        // Every row shows a value without any input (decision E6 defaults).
        let expected = [
            "hurts": "Nothing",
            "sleep": "7.5 h asleep",
            "work": "09:00–18:00",
            "office": "Asked each Sunday",
            "fixed": "Basketball",
            "kit": "Dumbbells to 24 kg",
        ]
        for (row, text) in expected {
            let button = app.buttons["onboarding.row.\(row)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), row)
            XCTAssertTrue(button.label.contains(text), "\(row): \(button.label)")
        }
        attach(app, "onboarding-confirm")

        app.buttons["onboarding.confirm"].tap()
        XCTAssertTrue(app.staticTexts["permissions.title"].waitForExistence(timeout: 5))
        attach(app, "onboarding-permissions")
        app.buttons["permissions.continue"].tap()

        // Today appears and the stored profile is confirmed.
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 10))
        let status = app.staticTexts["debug.launch"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("profile=confirmed"), status.label)
        attach(app, "today-after-onboarding")

        XCTAssertLessThan(Date().timeIntervalSince(started), 300, "onboarding took longer than 5 minutes")
    }

    @MainActor
    func testARowEditsInPlace() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-16T09:00:00Z", "-fixture", "new-install"]
        app.launch()

        XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 15))
        // The row sits below the fold on smaller screens; lists only build what's visible.
        let row = app.buttons["onboarding.row.longest"]
        for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("45 min"), row.label)
        row.tap()
        let stepper = app.steppers.firstMatch
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        if !stepper.isHittable { app.swipeUp() }
        stepper.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(row.label.contains("50 min"), row.label)
        // Still the same screen: editing never opens a new one.
        XCTAssertTrue(app.buttons["onboarding.confirm"].exists)
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
