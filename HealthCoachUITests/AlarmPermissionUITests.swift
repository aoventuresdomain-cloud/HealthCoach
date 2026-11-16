import XCTest

/// QA-2 (Gate 0a follow-up): with real AlarmKit in the simulator, allowing the
/// permission prompt sets the 14 test alarms, and the reconcile on the next
/// launch finds all 14 still registered.
final class AlarmPermissionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openSpikeTests() -> XCUIApplication {
        let app = XCUIApplication()
        // A confirmed profile, so the app opens on Today, where the Spike tests link lives.
        // The spike screen, not the planner, owns the alarms in this test (M2-02).
        app.launchArguments = ["-uitest", "-realAlarms", "-fixture", "week1-monday", "-spikeAlarms"]
        app.launch()
        let link = app.buttons["home.spikeTests"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        link.tap()
        return app
    }

    @MainActor
    private func result(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Every "Result: …" line on the Spike tests screen, for failure messages.
    @MainActor
    private func results(_ app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Result:'"))
            .allElementsBoundByIndex.map(\.label).joined(separator: " | ")
    }

    /// Waits up to `timeout` for `text` in a result line, tapping Allow on the
    /// AlarmKit prompt wherever the system shows it (Springboard or the app).
    @MainActor
    private func waitForResult(_ app: XCUIApplication, containing text: String, timeout: TimeInterval) -> Bool {
        let springboardAllow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if result(app, containing: text).exists { return true }
            if springboardAllow.exists {
                springboardAllow.tap()
            } else if app.alerts.buttons["Allow"].exists {
                app.alerts.buttons["Allow"].tap()
            }
            _ = result(app, containing: text).waitForExistence(timeout: 1)
        }
        return result(app, containing: text).exists
    }

    @MainActor
    func testAllowingAlarmsSetsFourteenThatSurviveARelaunch() throws {
        let monitor = addUIInterruptionMonitor(withDescription: "AlarmKit permission") { alert in
            let allow = alert.buttons["Allow"]
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }

        var app = openSpikeTests()
        let set = app.buttons["Set test alarms"]
        XCTAssertTrue(set.waitForExistence(timeout: 10))
        set.tap()
        app.swipeUp() // any interaction lets the interruption monitor run
        XCTAssertTrue(waitForResult(app, containing: "14 alarms set", timeout: 30), results(app))
        add(XCTAttachment(screenshot: app.screenshot()))

        app.terminate()
        app = openSpikeTests()
        XCTAssertTrue(waitForResult(app, containing: "All alarms set (14)", timeout: 20), results(app))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "alarms-after-relaunch"
        shot.lifetime = .keepAlways
        add(shot)

        // Leave one near alarm rather than 14 on the simulator.
        app.buttons["Clear later test alarms"].tap()
    }
}
