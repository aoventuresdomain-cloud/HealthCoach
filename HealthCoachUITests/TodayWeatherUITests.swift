import XCTest

/// M2-05 on Today: a rainy Tuesday shows the indoor session with a one-line
/// note, and "I'll run anyway" puts the run back.
final class TodayWeatherUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRainShowsTheIndoorSessionAndRunAnywayPutsTheRunBack() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-now", "2026-11-24T06:00:00Z", "-fixture", "week1-monday",
                               "-weather", "rain"]
        app.launch()
        let note = app.staticTexts["today.weatherSwap"]
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        XCTAssertTrue(note.label.contains("instead, same time"), note.label)
        let title = app.staticTexts["today.title"]
        XCTAssertFalse(title.label.lowercased().contains("run"), "the swapped title still names the run: \(title.label)")
        // QA-20: the timeline row follows the swap too.
        let row = app.descendants(matching: .any)["today.timeline.session"]
        for _ in 0..<4 where !row.exists { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertFalse(row.label.lowercased().contains("run"), "the timeline row still names the run: \(row.label)")
        XCTAssertTrue(row.label.contains(title.label.components(separatedBy: " at ").first ?? "∅"),
                      "row \(row.label) vs header \(title.label)")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "today-weather-swap"
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["today.runAnyway"].tap()
        XCTAssertTrue(note.waitForNonExistence(timeout: 5))
        XCTAssertTrue(title.label.lowercased().contains("run"), title.label)
        XCTAssertTrue(row.label.lowercased().contains("run"), row.label)
    }
}
