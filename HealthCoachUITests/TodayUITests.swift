import XCTest

/// Board M1-05: Today shows the right session for each day of week 1.
/// Expected names are phase-1.json's week 1 schedule (start Monday 23 Nov 2026).
/// `week1-monday` was onboarded Sunday 22 Nov (`confirmedOn`) and logs nothing, so by Friday Monday's Upper A has
/// passed and moved to the free Friday (E13, QA-15).
final class TodayUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private let week1: [(date: String, title: String)] = [
        ("2026-11-23", "Upper A at"),
        ("2026-11-24", "Run-walk at"),
        ("2026-11-25", "Basketball tonight"),
        ("2026-11-26", "Full body (light legs) at"),
        ("2026-11-27", "Upper A at"),
        ("2026-11-28", "Upper B at"),
        ("2026-11-29", "Walk in Hyde Park at"),
    ]

    @MainActor
    func testEachDayOfWeekOneShowsItsSession() throws {
        for day in week1 {
            let app = XCUIApplication()
            app.launchArguments = ["-uitest", "-now", "\(day.date)T07:00:00Z", "-fixture", "week1-monday"]
            app.launch()
            let title = app.staticTexts["today.title"]
            XCTAssertTrue(title.waitForExistence(timeout: 15), day.date)
            XCTAssertTrue(title.label.hasPrefix(day.title), "\(day.date): \(title.label)")
            // QA-31: a fixture launch finds its alarms already set, so no "missing" banner.
            XCTAssertFalse(app.descendants(matching: .any)["today.alarmBanner"].waitForExistence(timeout: 2), day.date)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "today-\(day.date)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }

    @MainActor
    func testRestDayOffersTomorrow() throws {
        // Mon, Tue and Thu logged, so Friday stays a rest day.
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-27T07:00:00Z", "-fixture", "week1-on-track"]
        app.launch()
        let next = app.buttons["today.seeTomorrow"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        next.tap()
        XCTAssertTrue(app.staticTexts["today.title"].label.hasPrefix("Upper B at"), app.staticTexts["today.title"].label)
        XCTAssertTrue(app.buttons["today.backToToday"].exists)
    }

    /// QA-31: the "missing, set again" reassurance still works when the store starts empty.
    @MainActor
    func testMissingAlarmsAreSetAgainWithTheFlag() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-23T06:20:00Z", "-fixture", "week1-monday", "-missingAlarms"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["today.alarmBanner"].waitForExistence(timeout: 5))
    }
}
