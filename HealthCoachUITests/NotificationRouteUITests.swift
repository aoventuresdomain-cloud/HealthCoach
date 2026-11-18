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
    /// opens next week's check-in (N1); taking the defaults is Next, then Looks good.
    @MainActor
    func testSundayPromptNotificationOpensTheCheckIn() throws {
        let app = launch(from: "sundayPrompt", now: "2026-11-22T17:00:00Z")
        let budget = EaseBudget("checkin-from-notification", maxTaps: 3, maxSeconds: 60, app: app)
        budget.notificationTap()
        let next = app.buttons["checkin.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15), "the check-in opens straight from the notification")
        budget.tap(next, newScreen: true)
        let done = app.buttons["checkin.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sunday.day.monday"].exists)
        budget.tap(done, newScreen: true)
        budget.finish(done: app.staticTexts["today.title"])
        XCTAssertTrue(app.buttons["today.checkIn"].waitForNonExistence(timeout: 5), "next week is checked in")
    }

    /// Morning brief, leave now and wind-down open Today, on Today's tab.
    @MainActor
    func testDayNotificationsOpenToday() throws {
        for kind in ["morningBrief", "leaveNow", "windDown"] {
            let app = launch(from: kind, now: "2026-11-23T06:30:00Z")
            XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15), kind)
            XCTAssertTrue(app.tabBars.buttons["Today"].isSelected, kind)
            XCTAssertFalse(app.buttons["checkin.next"].exists, "\(kind) opens no sheet")
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
        XCTAssertTrue(app.tabBars.buttons["Shopping"].isSelected, "N9b: the Shopping tab, not a Meals segment")
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

    /// F1 (N7): the photo-day notification opens the camera on Progress. Budget: the tap, 5 s.
    @MainActor
    func testPhotoDayOpensTheCamera() throws {
        // Monday 23 Nov 2026: week1-monday's first photo day.
        let app = launch(from: "photoDay", now: "2026-11-23T07:00:00Z")
        let budget = EaseBudget("photo-day", maxTaps: 1, maxSeconds: 5, app: app)
        budget.notificationTap()
        let shutter = app.buttons["photo.take.front"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 15), "the reminder opens the photo-day camera")
        budget.finish(done: shutter)
        app.buttons["photo.cancel"].firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons["Progress"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Progress"].isSelected, "closing the camera leaves Progress")
    }
}
