import XCTest

/// Board N9: a tapped notification opens its screen. Each test starts with
/// `-openFrom notification:<kind>`, which goes through the same
/// `NotificationRoute.destination(for:)` as the real tap (CoachCore tests
/// that the two agree for every kind).
final class NotificationRouteUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(from kind: String, now: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", now, "-fixture", "week1-monday",
                               "-openFrom", "notification:\(kind)"]
        app.launch()
        return app
    }

    /// W1 from the notification: Sunday 22 Nov 2026, 17:00 in London. The tap
    /// opens next week's check-in; taking the defaults is one more tap.
    @MainActor
    func testSundayPromptNotificationOpensTheCheckIn() throws {
        let app = launch(from: "sundayPrompt", now: "2026-11-22T17:00:00Z")
        let budget = EaseBudget("checkin-from-notification", maxTaps: 3, maxSeconds: 60, app: app)
        budget.notificationTap()
        let done = app.buttons["sunday.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "the check-in opens straight from the notification")
        XCTAssertTrue(app.buttons["sunday.day.monday"].exists)
        budget.tap(done, newScreen: true)
        budget.finish(done: app.staticTexts["today.title"])
        XCTAssertTrue(app.buttons["today.planWeek"].waitForNonExistence(timeout: 5), "next week is answered")
    }

    /// Morning brief, leave now and wind-down open Today, on Today's tab.
    @MainActor
    func testDayNotificationsOpenToday() throws {
        for kind in ["morningBrief", "leaveNow", "windDown"] {
            let app = launch(from: kind, now: "2026-11-23T06:30:00Z")
            XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15), kind)
            XCTAssertTrue(app.tabBars.buttons["Today"].isSelected, kind)
            XCTAssertFalse(app.buttons["sunday.done"].exists, "\(kind) opens no sheet")
            app.terminate()
        }
    }

    /// W5: the delivery reminder opens Meals on Shopping. Budget: the tap, 5 s.
    @MainActor
    func testDeliveryReminderOpensShopping() throws {
        let app = launch(from: "deliveryReminder", now: "2026-11-25T19:00:00Z")
        let budget = EaseBudget("delivery-reminder", maxTaps: 1, maxSeconds: 5, app: app)
        budget.notificationTap()
        let header = app.descendants(matching: .any)["shopping.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 15), "the reminder opens Shopping")
        XCTAssertTrue(app.tabBars.buttons["Meals"].isSelected)
        budget.finish(done: header)
    }

    /// K3: the checkpoint notification opens Progress with Ask the coach in view. Budget: the tap, 5 s.
    @MainActor
    func testCheckpointOpensAskTheCoach() throws {
        let app = launch(from: "checkpoint", now: "2026-12-26T19:00:00Z")
        let budget = EaseBudget("checkpoint", maxTaps: 1, maxSeconds: 5, app: app)
        budget.notificationTap()
        let ask = app.buttons["progress.askCoach"]
        XCTAssertTrue(ask.waitForExistence(timeout: 15), "the checkpoint opens Ask the coach")
        XCTAssertTrue(app.tabBars.buttons["Progress"].isSelected)
        budget.finish(done: ask)
        XCTAssertTrue(ask.isHittable, "Ask the coach is in view without a scroll")
    }
}
