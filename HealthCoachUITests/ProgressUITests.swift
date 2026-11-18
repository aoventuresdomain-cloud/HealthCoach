import XCTest

/// Board M4-03 (re-planned): photo day every 2 weeks, and "Ask the coach now"
/// opening the share sheet.
final class ProgressUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openProgress(now: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", now, "-fixture", "week1-monday"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["progress.weight"].waitForExistence(timeout: 5))
        // QA-30: SampleHealthReader's steps, 3,200 today and 8,100…8,700 before (mean 8,400).
        let steps = app.staticTexts["progress.steps"]
        XCTAssertTrue(steps.waitForExistence(timeout: 5))
        XCTAssertTrue(steps.label.hasPrefix("Steps: 3,200 today"), steps.label)
        // UI-12: the hero is the 7-day average alone, with its change since the start under it.
        XCTAssertTrue(app.staticTexts["progress.weight"].label.hasSuffix(" kg"), app.staticTexts["progress.weight"].label)
        XCTAssertTrue(app.staticTexts["progress.weightChange"].label.hasPrefix("7-day average"))
        return app
    }

    @MainActor
    func testPhotoDaySavesBothPosesAndIsThenDone() throws {
        // Monday 23 Nov 2026: the first day of week 1's 2-week block.
        let app = openProgress(now: "2026-11-23T07:00:00Z")
        let photoDay = app.buttons["progress.photoDay"]
        XCTAssertTrue(photoDay.waitForExistence(timeout: 5))
        photoDay.tap()
        // N7: a full-screen camera per pose ("Front · 1 of 2"), one hint line,
        // and a 3 s self-timer on the shutter; then one review screen.
        XCTAssertTrue(app.buttons["photo.take.front"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["photo.step"].label, "Front · 1 of 2")
        // The UI-test stand-in is a drawn figure, so the on-device check finds nobody.
        XCTAssertTrue(app.staticTexts["photo.hint"].waitForExistence(timeout: 5), "no pose hint")
        attach(app, "photo-camera")
        app.buttons["photo.take.front"].tap()
        XCTAssertTrue(app.staticTexts["photo.countdown"].waitForExistence(timeout: 2), "no self-timer")
        let side = app.buttons["photo.take.side"]
        XCTAssertTrue(side.waitForExistence(timeout: 8), "the side pose didn't follow the front")
        XCTAssertEqual(app.staticTexts["photo.step"].label, "Side · 2 of 2")
        side.tap()
        let save = app.buttons["photo.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 8), "no review screen after both poses")
        XCTAssertEqual(app.buttons["photo.retake.front"].label, "Retake")
        XCTAssertEqual(app.buttons["photo.retake.side"].label, "Retake")
        XCTAssertFalse(app.descendants(matching: .any)["photo.waist"].exists, "waist is off by default")
        attach(app, "photo-day")
        save.tap()

        // UI-12: photos are one disclosure row now (a button), not a text line.
        XCTAssertTrue(app.descendants(matching: .any)["progress.nextPhotos"].waitForExistence(timeout: 5))
        XCTAssertFalse(photoDay.exists)
        attach(app, "progress-after-photos")
    }

    /// N7: with the waist turned on in Preferences, the review has a stepper
    /// pre-filled at 90 cm, in 0.5 cm steps, with the measuring line; no typing.
    @MainActor
    func testWaistStepperOnPhotoDay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-23T07:00:00Z", "-fixture", "week1-monday"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        app.buttons["today.more"].tap()
        app.buttons["today.settings"].tap()
        let toggle = app.switches["prefs.waist"]
        for _ in 0..<4 where !(toggle.waitForExistence(timeout: 1) && toggle.isHittable) { app.swipeUp() }
        XCTAssertEqual(toggle.value as? String, "0", "waist is off by default")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["prefs.done"].tap()

        app.tabBars.buttons["Progress"].tap()
        let photoDay = app.buttons["progress.photoDay"]
        XCTAssertTrue(photoDay.waitForExistence(timeout: 5))
        photoDay.tap()
        XCTAssertTrue(app.buttons["photo.take.front"].waitForExistence(timeout: 5))
        app.buttons["photo.take.front"].tap()
        let side = app.buttons["photo.take.side"]
        XCTAssertTrue(side.waitForExistence(timeout: 8))
        side.tap()
        let waist = app.descendants(matching: .any)["photo.waist"]
        XCTAssertTrue(waist.waitForExistence(timeout: 8), "no waist row with the waist on")
        XCTAssertTrue(app.staticTexts["At the navel, after breathing out"].exists)
        XCTAssertEqual(waist.value as? String, "90.0 cm")
        app.steppers["photo.waist"].buttons.element(boundBy: 1).tap()
        XCTAssertEqual(waist.value as? String, "90.5 cm")
        XCTAssertEqual(app.keyboards.count, 0, "no typing (E4)")
        attach(app, "photo-waist")
        app.buttons["photo.save"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["progress.nextPhotos"].waitForExistence(timeout: 5))
    }

    /// N7: Photos opens straight onto a compare of the latest set against
    /// week 0, with a slider; the switch moves it to 4 weeks ago.
    @MainActor
    func testCompareAgainstWeekZeroAndFourWeeksAgo() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2027-01-04T09:00:00Z", "-fixture", "week7-photos"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.title"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Progress"].tap()
        let photos = app.descendants(matching: .any)["progress.nextPhotos"]
        for _ in 0..<4 where !(photos.waitForExistence(timeout: 1) && photos.isHittable) { app.swipeUp() }
        photos.tap()

        XCTAssertTrue(app.descendants(matching: .any)["compare.photos"].waitForExistence(timeout: 5))
        let slider = app.sliders["compare.slider"]
        XCTAssertTrue(slider.exists)
        let then = { (label: String) in app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch }
        XCTAssertTrue(then("Week 0 ·").exists, "not comparing with week 0 first")
        slider.adjust(toNormalizedSliderPosition: 0.3)
        attach(app, "compare-week0")

        app.buttons["4 weeks ago"].tap()
        XCTAssertTrue(then("4 weeks ago ·").waitForExistence(timeout: 3), "the switch didn't move to 4 weeks ago")
        attach(app, "compare-4-weeks")
    }

    @MainActor
    func testAskTheCoachOpensTheShareSheet() throws {
        let app = openProgress(now: "2026-11-23T07:00:00Z")
        let ask = app.buttons["progress.askCoach"]
        // The section sits at the bottom of a lazy list: scroll until it's built.
        for _ in 0..<6 where !(ask.waitForExistence(timeout: 1) && ask.isHittable) { app.swipeUp() }
        XCTAssertTrue(ask.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["coach.import"].exists, "Import sits under Ask the coach now")
        ask.tap()
        // The system share sheet.
        let sheet = app.otherElements["ActivityListView"]
        let copy = app.buttons["Copy"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5) || copy.waitForExistence(timeout: 5))
        attach(app, "ask-the-coach-share")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
