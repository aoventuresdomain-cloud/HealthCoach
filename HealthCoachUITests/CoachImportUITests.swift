import XCTest

/// Gate 1–2 checklist A17 (board M4-02): on Sunday the owner copies Claude's
/// reply and taps Import on Progress. A valid block changes next week's plan
/// (Thursday's full body is dropped) and shows a plain success line; a bad
/// one is refused in plain words and next week's plan is as it was. The
/// CoachCore twin is Week2HybridCoachTests.a17….
final class CoachImportUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Sunday 29 Nov 2026, 18:00 London (end of week 1), and Thursday of the
    /// week after, when full body is planned (week1-monday fixture, start 23 Nov).
    private let sunday = "2026-11-29T18:00:00Z"
    private let thursday = "2026-12-03T06:00:00Z"
    private let note = "Two uppers and two runs next week."

    private func reply(schemaVersion: Int) -> String {
        """
        Solid week. Skip full body next week while you settle in, and nudge the bench.
        BEGIN HEALTHCOACH BLOCK
        {"format": "healthcoach-coach-block", "schemaVersion": \(schemaVersion), "note": "\(note)",
         "dailyKcal": 2100, "dropSessions": ["full-body"],
         "loads": [{"exercise": "dumbbell-bench-press", "kg": 12}]}
        END HEALTHCOACH BLOCK
        """
    }

    @MainActor
    private func launch(now: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", now, "-fixture", "week1-monday"] + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func openProgress(_ app: XCUIApplication) {
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["progress.weight"].waitForExistence(timeout: 5))
    }

    /// Next Thursday's Today title, with whatever the earlier import stored.
    @MainActor
    private func thursdayTitle() -> (XCUIApplication, String) {
        let app = launch(now: thursday, extra: ["-keepCoachBlocks"])
        return (app, app.staticTexts["today.title"].label)
    }

    /// The coach section sits at the bottom of a lazy list: scroll until it's built.
    @MainActor
    private func scrollToImport(_ app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["coach.import"]
        for _ in 0..<6 where !(button.waitForExistence(timeout: 1) && button.isHittable) { app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        return button
    }

    @MainActor
    private func importReply(_ text: String) -> (XCUIApplication, String) {
        // Base64: a raw multi-line argument didn't arrive intact (first run of #60).
        let encoded = Data(text.utf8).base64EncodedString()
        let app = launch(now: sunday, extra: ["-clipboardBase64", encoded])
        let status = app.staticTexts["debug.launch"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("clip=\(text.utf8.count)"), status.label)
        openProgress(app)
        scrollToImport(app).tap()
        let result = app.staticTexts["coach.import.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        return (app, result.label)
    }

    @MainActor
    func testA17ValidReplyImportsAndShowsTheNextDay() throws {
        let (app, message) = importReply(reply(schemaVersion: 1))
        XCTAssertEqual(message, "Imported. The new plan starts tomorrow.")
        // Not in force until tomorrow, so no note yet.
        XCTAssertFalse(app.staticTexts["progress.coachNote"].exists)
        attach(app, "a17-imported")
        app.terminate()

        // Next week: full body is gone from Thursday (the moved Upper A takes the slot).
        let (next, title) = thursdayTitle()
        XCTAssertFalse(title.hasPrefix("Full body"), title)
        attach(next, "a17-thursday-changed")
        openProgress(next)
        _ = scrollToImport(next)
        let shown = next.staticTexts["progress.coachNote"]
        XCTAssertTrue(shown.waitForExistence(timeout: 5))
        XCTAssertEqual(shown.label, note)
        attach(next, "a17-coach-note")
    }

    @MainActor
    func testA17BadReplyIsRefusedAndNothingChanges() throws {
        let (app, message) = importReply(reply(schemaVersion: 2))
        // Refused for the version, not for a missing block (both end the same way).
        XCTAssertTrue(message.contains("format 2"), message)
        XCTAssertTrue(message.hasSuffix("Your plan hasn't changed."), message)
        attach(app, "a17-refused")
        app.terminate()

        // Next week is the baseline: full body still on Thursday, no coach note.
        let (next, title) = thursdayTitle()
        XCTAssertTrue(title.hasPrefix("Full body"), title)
        attach(next, "a17-thursday-unchanged")
        openProgress(next)
        _ = scrollToImport(next)
        XCTAssertFalse(next.staticTexts["progress.coachNote"].exists)
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
