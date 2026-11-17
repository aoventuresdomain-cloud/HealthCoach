import XCTest

/// QA-1 on Today: with no alarms set (permission denied), Today warns and
/// never says "all set"; with alarms set, there's no warning.
final class AlarmWarningUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-23T06:20:00Z", "-fixture", "week1-monday"] + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        return app
    }

    /// What was going on when an alarm check failed: app state (a crash shows
    /// as notRunning), alerts over the app, and the debug line.
    @MainActor
    private func diagnosis(_ app: XCUIApplication) -> String {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let status = app.staticTexts["debug.launch"]
        return "state=\(app.state.rawValue) appAlerts=\(app.alerts.count) "
            + "springboardAlerts=\(springboard.alerts.allElementsBoundByIndex.map(\.label)) "
            + "debug=\(status.exists ? status.label : "none")"
    }

    @MainActor
    func testDeniedAlarmsShowAWarningNeverAllSet() throws {
        let app = launch(["-denyAlarms"])
        let warning = app.staticTexts["today.alarmWarning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 10), diagnosis(app))
        XCTAssertTrue(warning.label.contains("No alarms set."), warning.label)
        XCTAssertTrue(app.links["today.openSettings"].exists || app.buttons["today.openSettings"].exists)
        let allSet = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'all set'"))
        XCTAssertEqual(allSet.count, 0)
        let status = app.staticTexts["debug.launch"]
        if status.exists { XCTAssertTrue(status.label.contains("alarms=none"), status.label) }

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "today-no-alarms-warning"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testAlarmsSetShowNoWarning() throws {
        let app = launch([])
        let status = app.staticTexts["debug.launch"]
        if status.waitForExistence(timeout: 5) {
            let reconciled = NSPredicate(format: "NOT (label CONTAINS 'alarms=pending')")
            let outcome = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: reconciled, object: status)], timeout: 10)
            XCTAssertEqual(outcome, .completed, diagnosis(app))
        }
        XCTAssertFalse(app.staticTexts["today.alarmWarning"].exists)
    }
}
