import XCTest

/// Board M1-01: proves the deterministic launch flags (QA test plan §3) work,
/// so later screens' UI tests can rely on them.
final class LaunchFlagsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(now: String, fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", now, "-fixture", fixture]
        app.launch()
        return app
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testClockAndFixtureAreInjected() throws {
        let app = launch(now: "2026-11-23T06:30:00Z", fixture: "week1-monday")
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 10))
        let status = app.staticTexts["debug.launch"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("now=2026-11-23T06:30:00Z"), status.label)
        XCTAssertTrue(status.label.contains("profile=confirmed"), status.label)
        XCTAssertTrue(status.label.contains("content=ok("), status.label)
        // Board M2-02: on open the planner reconciles 14 days of wake alarms
        // (Monday 23 Nov, 06:30 GMT: today's 07:50 alarm is still ahead).
        let fourteen = NSPredicate(format: "label CONTAINS 'alarms=14'")
        expectation(for: fourteen, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        attachScreenshot(app, named: "week1-monday")
    }

    @MainActor
    func testEachLaunchStartsFromItsOwnFixture() throws {
        // In-memory store: the previous test's confirmed profile must not leak.
        let app = launch(now: "2026-11-16T09:00:00Z", fixture: "new-install")
        let status = app.staticTexts["debug.launch"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("profile=unconfirmed"), status.label)
        XCTAssertTrue(status.label.contains("now=2026-11-16T09:00:00Z"), status.label)
    }
}
