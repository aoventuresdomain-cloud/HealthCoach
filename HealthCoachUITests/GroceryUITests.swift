import XCTest

/// Board N5 through the ease budget (design §2 W3, W4; QA-R4 J2.6, J2.7):
/// "Send to Reminders" writes one Shopping list, reused and never duplicated,
/// and in-store mode ticks items off from the top row with no scrolling.
final class GroceryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Until N9b lands, Shopping is a segment inside Meals: one tap more than
    /// the design's Shopping tab. The budget allows that one tap and says so.
    @MainActor
    private func hasShoppingTab(_ app: XCUIApplication) -> Bool {
        app.tabBars.buttons["Shopping"].exists
    }

    /// Launches on Today, then (outside the budget) visits Shopping once to
    /// answer N4's one-off shop question if it shows, reads the "N to get"
    /// count and goes back to Today. Returns the count.
    @MainActor
    private func launchAndWarmUp(_ app: XCUIApplication) -> Int {
        app.launchArguments = ["-uitest", "-now", "2026-11-23T07:00:00Z", "-fixture", "week1-monday"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        if hasShoppingTab(app) {
            app.tabBars.buttons["Shopping"].tap()
        } else {
            app.tabBars.buttons["Meals"].tap()
            app.segmentedControls["meals.tabs"].buttons["Shopping"].tap()
        }
        let askDone = app.buttons["ask.shop.done"]
        if askDone.waitForExistence(timeout: 2) { askDone.tap() }
        let header = app.staticTexts["shopping.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        // "Waitrose · 23 to get"
        let count = header.label.split(separator: "·").last
            .flatMap { Int($0.trimmingCharacters(in: .whitespaces).split(separator: " ").first ?? "") } ?? 0
        XCTAssertGreaterThan(count, 5, "header: \(header.label)")
        if !hasShoppingTab(app) {
            // Leave Meals on its first segment, as a fresh launch would.
            app.segmentedControls["meals.tabs"].buttons["Meals"].tap()
        }
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 5))
        return count
    }

    /// Today → Shopping through the budget. Tab bar and segmented control are
    /// system chrome, so their size isn't ours to check (E6 `system`).
    @MainActor
    private func openShopping(_ app: XCUIApplication, _ budget: EaseBudget) {
        if hasShoppingTab(app) {
            budget.tap(app.tabBars.buttons["Shopping"], newScreen: true, system: true)
        } else {
            budget.tap(app.tabBars.buttons["Meals"], newScreen: true, system: true)
            budget.tap(app.segmentedControls["meals.tabs"].buttons["Shopping"], system: true)
        }
        XCTAssertTrue(app.buttons["shopping.inStore"].waitForExistence(timeout: 5))
    }

    /// The Reminders permission prompt: "Allow Full Access" (or "OK" / "Allow").
    @MainActor
    private func allowButton(_ app: XCUIApplication) -> XCUIElement? {
        let allow = NSPredicate(format: "label BEGINSWITH 'Allow' OR label == 'OK'")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for alerts in [springboard.alerts, app.alerts] {
            let button = alerts.buttons.matching(allow).firstMatch
            if button.waitForExistence(timeout: 5) { return button }
        }
        return nil
    }

    @MainActor
    func testSendToRemindersMakesOneListAndReusesIt() throws {
        let app = XCUIApplication()
        // The first send is the first-ever: the permission prompt shows once.
        app.resetAuthorizationStatus(for: .reminders)
        let toGet = launchAndWarmUp(app)
        let extra = hasShoppingTab(app) ? 0 : 1
        let note = extra == 0 ? nil : "+1 tap: Shopping segment until N9b"

        // W3, first time: 2 taps plus one system alert (allowed, counted).
        let first = EaseBudget("send-to-reminders-first", maxTaps: 3 + extra, maxSeconds: 10, maxAlerts: 1, app: app)
        openShopping(app, first)
        first.tap(app.buttons["shopping.reminders"])
        let allow = try XCTUnwrap(allowButton(app), "no Reminders permission prompt")
        first.answerAlert(allow)
        let sent = app.staticTexts["shopping.sent"]
        first.finish(done: sent, note: note)
        XCTAssertEqual(sent.label, "Sent to Reminders · Shopping")
        // Read back from Reminders: one Shopping list, every item still to get.
        XCTAssertEqual(sent.value as? String, "1 list · \(toGet) items")

        // Sending again on the same screen changes nothing: no second list, no duplicates.
        app.buttons["shopping.reminders"].tap()
        let again = NSPredicate(format: "value == %@", "1 list · \(toGet) items")
        expectation(for: again, evaluatedWith: sent)
        waitForExpectations(timeout: 5)

        // W3 every week after: 2 taps, no alert. The list is found again, not remade.
        app.terminate()
        _ = launchAndWarmUp(app)
        let weekly = EaseBudget("send-to-reminders", maxTaps: 2 + extra, maxSeconds: 10, app: app)
        openShopping(app, weekly)
        weekly.tap(app.buttons["shopping.reminders"])
        weekly.finish(done: app.staticTexts["shopping.sent"], note: note)
        XCTAssertEqual(app.staticTexts["shopping.sent"].value as? String, "1 list · \(toGet) items")
        XCTAssertFalse(app.staticTexts["shopping.remindersProblem"].exists)
    }

    @MainActor
    func testInStoreTicksFromTheTopWithNoScrolling() throws {
        let app = XCUIApplication()
        let toGet = launchAndWarmUp(app)
        let extra = hasShoppingTab(app) ? 0 : 1
        let note = extra == 0 ? nil : "+1 tap: Shopping segment until N9b"

        // W4: 2 taps plus 1 per item, 20 s for 5 items, 0 scrolls.
        let budget = EaseBudget("shop-in-store", maxTaps: 7 + extra, maxSeconds: 20, app: app)
        openShopping(app, budget)
        budget.tap(app.buttons["shopping.inStore"], newScreen: true)
        XCTAssertTrue(app.descendants(matching: .any)["instore.view"].waitForExistence(timeout: 5))
        let items = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'instore.item.'"))
        for _ in 0..<5 {
            // The next item is always the top row.
            let top = items.firstMatch
            XCTAssertTrue(top.waitForExistence(timeout: 5))
            let id = top.identifier
            budget.tap(top)
            // Ticked items leave.
            XCTAssertTrue(app.buttons[id].waitForNonExistence(timeout: 5), "\(id) still shown")
        }
        budget.finish(done: app.navigationBars.staticTexts["\(toGet - 5) to get"], note: note)
        // In-store hides the shop's search links. Scoped to the in-store view:
        // the list underneath the full-screen cover still has its own links.
        let inStore = app.descendants(matching: .any)["instore.view"]
        XCTAssertFalse(inStore.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'shopping.search.'")).firstMatch.exists)

        // Back on the list, the five are ticked.
        app.buttons["instore.close"].tap()
        let header = app.staticTexts["shopping.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(header.label.hasSuffix("· \(toGet - 5) to get"), header.label)
    }
}
