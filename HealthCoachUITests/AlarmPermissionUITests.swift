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
        app.launchArguments = ["-uitest", "-realAlarms"]
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

    /// Taps Allow on the AlarmKit prompt wherever the system shows it. The
    /// interruption monitor covers the app-hosted case; Springboard the rest.
    @MainActor
    private func allowAlarmsIfAsked(_ app: XCUIApplication) {
        let springboardAllow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        if springboardAllow.waitForExistence(timeout: 5) {
            springboardAllow.tap()
            return
        }
        let appAllow = app.alerts.buttons["Allow"]
        if appAllow.exists { appAllow.tap() }
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
        allowAlarmsIfAsked(app)
        app.swipeUp() // any interaction lets the interruption monitor run
        XCTAssertTrue(result(app, containing: "14 alarms set").waitForExistence(timeout: 20),
                      app.debugDescription)
        add(XCTAttachment(screenshot: app.screenshot()))

        app.terminate()
        app = openSpikeTests()
        XCTAssertTrue(result(app, containing: "All alarms set (14)").waitForExistence(timeout: 20),
                      app.debugDescription)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "alarms-after-relaunch"
        shot.lifetime = .keepAlways
        add(shot)

        // Leave one near alarm rather than 14 on the simulator.
        app.buttons["Clear later test alarms"].tap()
    }
}
