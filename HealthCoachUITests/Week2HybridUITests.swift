import XCTest

/// Gate 1–2 §A, the simulated week on Today: A1, A5, A7 and A8–A11 for the hybrid
/// week 2 (office Mon, Tue, Thu; early Tue 08:00; late Thu 19:00), one launch per
/// step on the injected clock. Each step attaches a named shot (`a1-…` to `a11-…`)
/// for the round's evidence. The CoachCore twins (`Gate1WeekTests`,
/// `Week2HybridPlannerTests`) check the same week's numbers; the times here are theirs.
///
/// `week2-hybrid-week` holds the week's logs (Upper A Mon, run Tue, the moved full
/// body Fri, Upper B Sat). Logs after `-now` are left out, so each launch sees only
/// what has been done by then. London is on UTC in November, so `Z` times are local.
final class Week2HybridUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ now: String, fixture: String = "week2-hybrid-week") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", now, "-fixture", fixture]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15), now)
        return app
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits for the debug line to finish the alarm check, then returns it.
    @MainActor
    private func status(_ app: XCUIApplication) -> String {
        let line = app.staticTexts["debug.launch"]
        expectation(for: NSPredicate(format: "NOT (label CONTAINS 'alarms=pending')"), evaluatedWith: line)
        waitForExpectations(timeout: 10)
        return line.label
    }

    @MainActor
    private func title(_ app: XCUIApplication) -> String { app.staticTexts["today.title"].label }

    @MainActor
    private func wakeRow(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["today.timeline.wake"]
    }

    // MARK: A1 · Sun 22 Nov 18:00

    @MainActor
    func testA1SundayPromptThenTheWeeksPlan() throws {
        let app = launch("2026-11-22T18:00:00Z", fixture: "week2-hybrid-sunday")
        let card = app.buttons["today.checkIn"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let started = Date()
        card.tap()
        // N1: the weekend card is the check-in; screen 2 holds the office days.
        let next = app.buttons["checkin.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        let monday = app.buttons["sunday.day.monday"]
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        shot(app, "a1-sunday-prompt")
        monday.tap()
        app.buttons["sunday.day.tuesday"].tap()
        app.buttons["sunday.day.thursday"].tap()
        app.buttons["checkin.done"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "the plan shows straight after")
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertLessThan(elapsed, 20, "Sunday prompt took \(elapsed) s")
        // A2's count on the debug line: 7–14 days of alarms registered.
        let line = status(app)
        let count = line.firstMatch(of: /alarms=(\d+)/).flatMap { Int($0.1) }
        XCTAssertTrue((7...14).contains(count ?? 0), line)
        shot(app, "a1-week-planned")
    }

    // MARK: A5 · Tue 07:00

    @MainActor
    func testA5TuesdayRunBeforeTheEarlyStart() throws {
        let app = launch("2026-11-24T07:00:00Z")
        XCTAssertEqual(title(app), "Run-walk at 06:50")
        XCTAssertTrue(wakeRow(app).label.contains("06:35"), wakeRow(app).label)
        XCTAssertTrue(app.descendants(matching: .any)["today.timeline.leave"].label.contains("07:35"))
        shot(app, "a5-tuesday-run")
    }

    // MARK: A7 · Wed 07:00

    @MainActor
    func testA7WednesdayRestNoAlarm() throws {
        let app = launch("2026-11-25T07:00:00Z")
        XCTAssertTrue(title(app).hasPrefix("Basketball"), title(app))
        XCTAssertFalse(wakeRow(app).exists, "no alarm on Wednesday")
        shot(app, "a7-wednesday-rest")
    }

    // MARK: A8–A9 · Thu 21:00 move, Fri 07:00 hold (QA-15)

    @MainActor
    func testA8A9MissedFullBodyMovesToFridayAndHolds() throws {
        // Thu 21:00, full body not logged: too late tonight, so it moves to Friday 08:05.
        let thursday = launch("2026-11-26T21:00:00Z")
        let thursdayLine = status(thursday)
        XCTAssertTrue(thursdayLine.contains("next=2026-11-27T07:50:00Z"), thursdayLine)
        XCTAssertEqual(title(thursday), "Rest day")
        shot(thursday, "a8-thursday-night")
        thursday.buttons["today.seeTomorrow"].tap()
        XCTAssertEqual(title(thursday), "Full body (light legs) at 08:05")
        XCTAssertTrue(wakeRow(thursday).label.contains("07:50"), wakeRow(thursday).label)
        shot(thursday, "a8-moved-to-friday")
        thursday.terminate()

        // Fri 07:00: still there, same start, and the same alarm Thursday night set.
        let friday = launch("2026-11-27T07:00:00Z")
        XCTAssertEqual(title(friday), "Full body (light legs) at 08:05")
        XCTAssertTrue(friday.buttons["today.start"].exists)
        XCTAssertTrue(wakeRow(friday).label.contains("07:50"), wakeRow(friday).label)
        let fridayLine = status(friday)
        XCTAssertTrue(fridayLine.contains("next=2026-11-27T07:50:00Z"), fridayLine)
        shot(friday, "a9-friday-holds")
    }

    // MARK: A10–A11 · the weekend

    @MainActor
    func testA10A11TheWeekend() throws {
        let saturday = launch("2026-11-28T07:00:00Z")
        XCTAssertEqual(title(saturday), "Upper B at 09:00")
        XCTAssertTrue(wakeRow(saturday).label.contains("08:45"), wakeRow(saturday).label)
        XCTAssertTrue(status(saturday).contains("next=2026-11-28T08:45:00Z"))
        shot(saturday, "a10-saturday-upper-b")
        saturday.terminate()

        let sunday = launch("2026-11-29T07:00:00Z")
        XCTAssertTrue(title(sunday).hasPrefix("Walk in Hyde Park at 09:00"), title(sunday))
        XCTAssertFalse(wakeRow(sunday).exists, "no alarm for the optional walk")
        // QA-33: the card says the walk is optional, once, in its meta line.
        let meta = sunday.staticTexts["today.meta"]
        XCTAssertTrue(meta.waitForExistence(timeout: 5))
        XCTAssertEqual(meta.label, "30 min · optional")
        shot(sunday, "a11-sunday-walk")
    }
}
