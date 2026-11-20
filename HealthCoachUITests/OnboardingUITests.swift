import XCTest

/// Board M1-04: onboarding confirms in well under 5 minutes of taps with every
/// default pre-filled, and the result is stored in the profile record.
final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDefaultsArePreFilledAndTwoTapsConfirm() throws {
        let started = Date()
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-16T09:00:00Z", "-fixture", "new-install"]
        app.launch()

        XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 15))
        // Every row shows a value without any input (decision E6 defaults).
        // Ordered top to bottom: a Dictionary's order is random per run, and a
        // row scrolled above the fold is never found by swiping up again.
        // UI-12: "Check these 5" first; the other seven sit behind onboarding.more.
        let toCheck: [(row: String, text: String)] = [
            ("paperStart", "16 Nov"),
            ("sleep", "7.5 h asleep"),
            ("work", "09:00–18:00"),
            ("hurts", "Nothing"),
        ]
        let rest: [(row: String, text: String)] = [
            ("you", "178 cm · 82 kg"),
            ("office", "Asked each Sunday"),
            ("fixed", "Basketball"),
            ("kit", "Dumbbells to 24 kg"),
        ]
        XCTAssertFalse(app.buttons["onboarding.row.you"].exists, "confirmed rows start folded away")
        for (row, text) in toCheck {
            let button = app.buttons["onboarding.row.\(row)"]
            scrollIntoView(button, in: app)
            XCTAssertTrue(button.exists && button.isHittable, row)
            XCTAssertTrue(button.label.contains(text), "\(row): \(button.label)")
        }
        attach(app, "onboarding-confirm")
        let more = app.buttons["onboarding.more"]
        scrollIntoView(more, in: app)
        more.tap()
        for (row, text) in rest {
            let button = app.buttons["onboarding.row.\(row)"]
            // Lists only build what's on screen: scroll down to it, and back up
            // if it is already above the fold.
            scrollIntoView(button, in: app)
            XCTAssertTrue(button.exists && button.isHittable, row)
            XCTAssertTrue(button.label.contains(text), "\(row): \(button.label)")
        }
        attach(app, "onboarding-confirm-more")

        // "Looks right" sits in the bottom bar, never in the list: no scrolling to reach it.
        // Tap it only once the screen is still and nothing covers it, and if the
        // permissions screen doesn't follow, record what was on screen instead of guessing.
        let confirm = app.buttons["onboarding.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "no Looks right button")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(springboard.alerts.firstMatch.exists,
                       "a system alert covers onboarding: \(springboard.alerts.firstMatch.label)")
        XCTAssertTrue(confirm.isHittable, "Looks right is covered: \(confirm.frame)")
        confirm.tap()
        let permissions = app.staticTexts["permissions.title"]
        if !permissions.waitForExistence(timeout: 5) {
            attach(app, "onboarding-after-confirm")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "onboarding-after-confirm-tree"
            tree.lifetime = .keepAlways
            add(tree)
            XCTFail("Looks right didn't open the permissions screen; still on onboarding: \(app.staticTexts["onboarding.title"].exists)")
            return
        }
        attach(app, "onboarding-permissions")
        app.buttons["permissions.continue"].tap()

        // Today appears and the stored profile is confirmed.
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 10))
        let status = app.staticTexts["debug.launch"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("profile=confirmed"), status.label)
        attach(app, "today-after-onboarding")

        XCTAssertLessThan(Date().timeIntervalSince(started), 300, "onboarding took longer than 5 minutes")
    }

    @MainActor
    func testARowEditsInPlace() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-16T09:00:00Z", "-fixture", "new-install"]
        app.launch()

        XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 15))
        // The row sits below the fold on smaller screens; lists only build what's visible.
        let row = app.buttons["onboarding.row.longest"]
        for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("45 min"), row.label)
        row.tap()
        let stepper = app.steppers.firstMatch
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        if !stepper.isHittable { app.swipeUp() }
        stepper.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(row.label.contains("50 min"), row.label)
        // Still the same screen: editing never opens a new one.
        XCTAssertTrue(app.buttons["onboarding.confirm"].exists)
    }

    /// Scrolls until `element` is on screen and hittable. When the row is already built,
    /// its frame says which way to go; otherwise it lies below (lists build lazily
    /// downwards), then above. Each step is a slow quarter-screen drag held at the end, so
    /// there is no momentum: a row can't fly past the visible part of the list between
    /// checks, and the list is still when the next check (or a tap) happens. `app.swipeUp()`
    /// flicks with momentum, which skipped rows and cost up to 200 s of swiping.
    @MainActor
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        var downwards = true // reveal rows further down the list first
        for step in 0..<24 {
            if element.waitForExistence(timeout: 0.5), element.isHittable { return }
            if element.exists, !element.frame.isEmpty {
                downwards = element.frame.midY > window.midY
            } else if step == 12 {
                downwards = false // not below: look above
            }
            drag(app, revealingBelow: downwards)
        }
    }

    /// One slow drag of a quarter of the screen, held so the list stops where the finger does.
    @MainActor
    private func drag(_ app: XCUIApplication, revealingBelow: Bool) {
        let low = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let high = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        let (from, to) = revealingBelow ? (low, high) : (high, low)
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
