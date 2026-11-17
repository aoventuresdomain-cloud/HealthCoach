import XCTest

/// QA-2 (Gate 0a follow-up): with real AlarmKit in the simulator, allowing the
/// permission prompt sets the 14 test alarms, and the reconcile on the next
/// launch finds all 14 still registered.
final class AlarmPermissionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// QA-27: this is the suite's only real-AlarmKit test. When it fails part
    /// way, a system alert (the AlarmKit permission prompt, or a test alarm
    /// ringing) can stay over the simulator and keep the next tests' app
    /// inactive, so their launch-time reconcile never runs. Whatever happened,
    /// leave no alert up and no test alarm set.
    override func tearDown() async throws {
        await MainActor.run {
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for _ in 0..<3 {
                let alert = springboard.alerts.firstMatch
                guard alert.waitForExistence(timeout: 1) else { break }
                let allow = alert.buttons["Allow"]
                (allow.exists ? allow : alert.buttons.element(boundBy: 0)).tap()
            }
            let app = XCUIApplication()
            let clearAll = app.buttons["Clear all test alarms"]
            if app.state == .runningForeground, clearAll.exists {
                if !clearAll.isHittable { app.swipeUp() }
                clearAll.tap()
            }
            app.terminate()
        }
        try await super.tearDown()
    }

    @MainActor
    private func openSpikeTests() -> XCUIApplication {
        let app = XCUIApplication()
        // A confirmed profile, so the app opens on Today, where the Spike tests link lives.
        // The spike screen, not the planner, owns the alarms in this test (M2-02).
        app.launchArguments = ["-uitest", "-realAlarms", "-fixture", "week1-monday", "-spikeAlarms"]
        app.launch()
        // UI-12: the spike link is in Today's ⋯ menu (M0-11b: only under -spikeAlarms).
        let more = app.buttons["today.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        let link = app.buttons["home.spikeTests"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
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
        if !set.waitForExistence(timeout: 10) {
            // #60 at 45f0d1f failed here once, on the suite's first launch. Keep
            // what was on screen so a repeat shows the cause, not just the line.
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "spike-screen-missing"
            shot.lifetime = .keepAlways
            add(shot)
            let status = app.staticTexts["debug.launch"]
            XCTFail("No Set test alarms button. debug: \(status.exists ? status.label : "none"); "
                    + "spike link still on screen: \(app.buttons["home.spikeTests"].exists); "
                    + "alerts: \(app.alerts.count) app, "
                    + "\(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.count) springboard")
        }
        set.tap()
        app.swipeUp() // any interaction lets the interruption monitor run
        XCTAssertTrue(waitForResult(app, containing: "14 alarms set", timeout: 30),
                      results(app) + " | state=\(app.state.rawValue) springboardAlerts="
                      + "\(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.allElementsBoundByIndex.map(\.label))")
        add(XCTAttachment(screenshot: app.screenshot()))

        app.terminate()
        app = openSpikeTests()
        XCTAssertTrue(waitForResult(app, containing: "All alarms set (14)", timeout: 20), results(app))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "alarms-after-relaunch"
        shot.lifetime = .keepAlways
        add(shot)

        // QA-12: cancel every test alarm, so none rings over later tests' screenshots.
        let clearAll = app.buttons["Clear all test alarms"]
        if !clearAll.isHittable { app.swipeUp() }
        clearAll.tap()
        XCTAssertTrue(waitForResult(app, containing: "Cleared all alarms. 0 alarms set", timeout: 10), results(app))
    }
}
