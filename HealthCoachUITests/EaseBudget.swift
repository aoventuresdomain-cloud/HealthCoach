import XCTest

/// Board N9: counts the person's interactions for one daily job and checks
/// them against its budget. The method is docs/qa/ease-budget-method.md (QA);
/// the budgets and rules E1–E6 are docs/design/ease-budget.md.
///
/// Between `init` and `finish` a test touches the app only through this
/// helper: never `.tap()` directly (QA greps for it in review). Tests must set
/// `continueAfterFailure = false`: a failed `tap` guard doesn't tap, so later
/// steps would otherwise fail with a confusing message.
@MainActor
final class EaseBudget {
    let job: String
    let maxTaps: Int
    let maxSeconds: Double
    /// Design E3, E4, E5: all 0 unless the job's budget raises them.
    let maxScrolls: Int, maxChars: Int, maxAlerts: Int
    private(set) var taps = 0, scrolls = 0, chars = 0, screens = 1, alerts = 0

    /// Design E6: the smallest control we let a person tap, by its accessibility frame.
    static let minimumSide: CGFloat = 44
    /// How many swipes `scroll` tries before it gives up.
    static let maximumSwipes = 10

    private let app: XCUIApplication

    init(_ job: String, maxTaps: Int, maxSeconds: Double,
         maxScrolls: Int = 0, maxChars: Int = 0, maxAlerts: Int = 0,
         app: XCUIApplication = XCUIApplication()) {
        self.job = job
        self.maxTaps = maxTaps
        self.maxSeconds = maxSeconds
        self.maxScrolls = maxScrolls
        self.maxChars = maxChars
        self.maxAlerts = maxAlerts
        self.app = app
    }

    // MARK: - Interactions

    /// One tap. Fails if `e` isn't hittable already: XCUITest would scroll to
    /// it first, which would hide a scroll from E3. Unless `system`, fails if
    /// `e` is smaller than 44 × 44 pt (E6). `newScreen` adds a screen read.
    func tap(_ e: XCUIElement, newScreen: Bool = false, system: Bool = false,
             file: StaticString = #filePath, line: UInt = #line) {
        guard e.exists, e.isHittable else {
            XCTFail("\(job): \(describe(e)) isn't on screen without a scroll (E3)", file: file, line: line)
            return
        }
        if !system {
            let frame = e.frame
            XCTAssertTrue(frame.width >= Self.minimumSide && frame.height >= Self.minimumSide,
                          "\(job): \(describe(e)) is \(Int(frame.width)) × \(Int(frame.height)) pt, under 44 × 44 (E6)",
                          file: file, line: line)
        }
        e.tap()
        taps += 1
        if newScreen { screens += 1 }
    }

    /// Answers a system alert: one tap and one alert (E5), size not checked.
    func answerAlert(_ button: XCUIElement, newScreen: Bool = false,
                     file: StaticString = #filePath, line: UInt = #line) {
        tap(button, newScreen: newScreen, system: true, file: file, line: line)
        alerts += 1
    }

    /// Focuses `e` (one tap) and types `text` (its characters cost time, E4).
    func type(_ e: XCUIElement, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        tap(e, file: file, line: line)
        e.typeText(text)
        chars += text.count
    }

    /// Swipes `e` up until `target` is hittable; one scroll per swipe.
    func scroll(_ e: XCUIElement, to target: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        var swipes = 0
        while !(target.exists && target.isHittable) && swipes < Self.maximumSwipes {
            e.swipeUp()
            swipes += 1
        }
        scrolls += swipes
        XCTAssertTrue(target.exists && target.isHittable,
                      "\(job): \(describe(target)) still not on screen after \(swipes) swipes", file: file, line: line)
    }

    // MARK: - Time model (QA method §3)

    static let tapSeconds = 1.1, screenSeconds = 1.5, scrollSeconds = 1.0, charSeconds = 0.3, alertSeconds = 2.0

    static func modelSeconds(taps: Int, screens: Int, scrolls: Int, chars: Int, alerts: Int) -> Double {
        tapSeconds * Double(taps) + screenSeconds * Double(screens) + scrollSeconds * Double(scrolls)
            + charSeconds * Double(chars) + alertSeconds * Double(alerts)
    }

    var modelSeconds: Double {
        Self.modelSeconds(taps: taps, screens: screens, scrolls: scrolls, chars: chars, alerts: alerts)
    }

    /// "checkin · 3 taps · 0 scrolls · 0 chars · 0 alerts · 7.8 s model · budget 60 s", plus any note ("+6 s timer").
    static func resultLine(job: String, taps: Int, scrolls: Int, chars: Int, alerts: Int,
                           modelSeconds: Double, maxSeconds: Double, note: String? = nil) -> String {
        let budget = maxSeconds.rounded() == maxSeconds ? String(Int(maxSeconds)) : String(format: "%.1f", maxSeconds)
        var line = "\(job) · \(taps) taps · \(scrolls) scrolls · \(chars) chars · \(alerts) alerts · "
            + String(format: "%.1f", modelSeconds) + " s model · budget \(budget) s"
        if let note { line += " · \(note)" }
        return line
    }

    // MARK: - Done

    /// Asserts the done state and every limit, then attaches the screenshot
    /// `ease-<job>` and the result line, both kept, for the round record.
    /// `note` is time outside the model, such as "+6 s timer".
    func finish(done: XCUIElement, note: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        // Animations are off under -uitest; the short wait only absorbs the last screen's appearance.
        XCTAssertTrue(done.waitForExistence(timeout: 5), "\(job): done state \(describe(done)) not shown",
                      file: file, line: line)
        let model = modelSeconds
        let result = Self.resultLine(job: job, taps: taps, scrolls: scrolls, chars: chars, alerts: alerts,
                                     modelSeconds: model, maxSeconds: maxSeconds, note: note)
        XCTAssertLessThanOrEqual(taps, maxTaps, "\(job): taps over budget (E1). \(result)", file: file, line: line)
        XCTAssertLessThanOrEqual(model, maxSeconds + 1e-9, "\(job): time over budget (E2). \(result)", file: file, line: line)
        XCTAssertLessThanOrEqual(scrolls, maxScrolls, "\(job): scrolled (E3). \(result)", file: file, line: line)
        XCTAssertLessThanOrEqual(chars, maxChars, "\(job): typed (E4). \(result)", file: file, line: line)
        XCTAssertLessThanOrEqual(alerts, maxAlerts, "\(job): alerts (E5). \(result)", file: file, line: line)
        XCTAssertEqual(app.keyboards.count, 0, "\(job): keyboard still up at the end (E4)", file: file, line: line)

        XCTContext.runActivity(named: "Ease budget: \(result)") { activity in
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "ease-\(job)"
            shot.lifetime = .keepAlways
            activity.add(shot)
            let text = XCTAttachment(string: result)
            text.name = "ease-\(job)-result"
            text.lifetime = .keepAlways
            activity.add(text)
        }
    }

    private func describe(_ e: XCUIElement) -> String {
        let id = e.identifier
        return id.isEmpty ? "'\(e.label)'" : id
    }
}
