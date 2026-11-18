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
        // (Monday 23 Nov, 06:30 GMT: today's 07:50 alarm is still ahead). Decision
        // E14: only the 8 training days ring (no alarm on home Wed/Fri or the Sunday walk).
        let alarmsSet = NSPredicate(format: "label CONTAINS 'alarms=8'")
        expectation(for: alarmsSet, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        // Board M2-04: the 7-day weight average from (sample) Health data:
        // 82.4–83.0 kg over the last 7 days.
        expectation(for: NSPredicate(format: "label CONTAINS 'weight=82.7'"), evaluatedWith: status)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(status.label.contains("held=0"), status.label)
        attachScreenshot(app, named: "week1-monday")
    }

    @MainActor
    func testPastTheLastWeekThePlanHolds() throws {
        // QA-17 (E13): with Phases 1–3 chained (C6) the plan runs 20 weeks from
        // 23 Nov. Monday 19 Apr 2027 is plan week 22, past Phase 3's last week,
        // so the plan holds at it and says so. (11 Jan, the old date, is now
        // Phase 2 week 2: nothing to hold.)
        let app = launch(now: "2027-04-19T06:00:00Z", fixture: "week1-monday")
        let status = app.staticTexts["debug.launch"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("held=1"), status.label)
    }

    @MainActor
    func testRainSwapsTuesdaysRunIndoorsAndOfflineChangesNothing() throws {
        // Board M2-03. Tuesday 24 Nov (week 1) has run-1 outdoors at about 08:15.
        for (weather, expected) in [("rain", "weather=swap(indoor-circuit)"), ("offline", "weather=noForecast")] {
            let app = XCUIApplication()
            app.launchArguments = ["-uitest", "-now", "2026-11-24T06:00:00Z", "-fixture", "week1-monday",
                                   "-weather", weather]
            app.launch()
            let status = app.staticTexts["debug.launch"]
            XCTAssertTrue(status.waitForExistence(timeout: 10))
            expectation(for: NSPredicate(format: "label CONTAINS %@", expected), evaluatedWith: status)
            waitForExpectations(timeout: 10)
            // The swap runs after the alarm reconcile and never touches it.
            XCTAssertFalse(status.label.contains("alarms=none"), status.label)
            XCTAssertFalse(status.label.contains("alarms=pending"), status.label)
            app.terminate()
        }
    }

    @MainActor
    func testWeekTwoHybridFixtureLoadsItsWeek() throws {
        // Gate 1 §A fixture: office Mon/Tue/Thu from the fixture's week answers.
        // Monday 06:30 shows Upper A; the CoachCore twin (Gate1WeekTests) checks the numbers.
        let app = launch(now: "2026-11-23T06:30:00Z", fixture: "week2-hybrid")
        let title = app.staticTexts["today.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(title.label.hasPrefix("Upper A at"), title.label)
        let status = app.staticTexts["debug.launch"]
        expectation(for: NSPredicate(format: "NOT (label CONTAINS 'alarms=pending')"), evaluatedWith: status)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(status.label.contains("alarms=none"), status.label)
        attachScreenshot(app, named: "week2-hybrid-monday")
        app.terminate()
        // Its answers don't leak: week 1's all-home plan still has 8 alarms.
        let next = launch(now: "2026-11-23T06:30:00Z", fixture: "week1-monday")
        expectation(for: NSPredicate(format: "label CONTAINS 'alarms=8'"), evaluatedWith: next.staticTexts["debug.launch"])
        waitForExpectations(timeout: 10)
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
