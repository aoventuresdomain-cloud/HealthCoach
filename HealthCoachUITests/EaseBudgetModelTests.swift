import XCTest

/// QA's self-test for the ease budget's time model: fixed counts give known
/// numbers, so a typo in a coefficient fails CI. No app launch.
final class EaseBudgetModelTests: XCTestCase {
    @MainActor
    func testCoefficientsAreTheMethodsOnes() {
        XCTAssertEqual(EaseBudget.modelSeconds(taps: 1, screens: 0, scrolls: 0, chars: 0, alerts: 0), 1.1, accuracy: 1e-9)
        XCTAssertEqual(EaseBudget.modelSeconds(taps: 0, screens: 1, scrolls: 0, chars: 0, alerts: 0), 1.5, accuracy: 1e-9)
        XCTAssertEqual(EaseBudget.modelSeconds(taps: 0, screens: 0, scrolls: 1, chars: 0, alerts: 0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(EaseBudget.modelSeconds(taps: 0, screens: 0, scrolls: 0, chars: 1, alerts: 0), 0.3, accuracy: 1e-9)
        XCTAssertEqual(EaseBudget.modelSeconds(taps: 0, screens: 0, scrolls: 0, chars: 0, alerts: 1), 2.0, accuracy: 1e-9)
        XCTAssertEqual(EaseBudget.modelSeconds(taps: 2, screens: 3, scrolls: 4, chars: 5, alerts: 6), 24.2, accuracy: 1e-9)
    }

    /// The model times printed in docs/design/ease-budget.md §2.
    @MainActor
    func testTheDesignDocsNumbers() {
        // D2 start today's session: 1 tap, launch screen + player.
        XCTAssertEqual(EaseBudget.modelSeconds(taps: 1, screens: 2, scrolls: 0, chars: 0, alerts: 0), 4.1, accuracy: 1e-9)
        // W1 Sunday check-in, default: 3 taps over 3 screens.
        XCTAssertEqual(EaseBudget.modelSeconds(taps: 3, screens: 3, scrolls: 0, chars: 0, alerts: 0), 7.8, accuracy: 1e-9)
        // F1 photo day: 4 taps over 4 screens.
        XCTAssertEqual(EaseBudget.modelSeconds(taps: 4, screens: 4, scrolls: 0, chars: 0, alerts: 0), 10.4, accuracy: 1e-9)
    }

    @MainActor
    func testTheResultLine() {
        XCTAssertEqual(EaseBudget.resultLine(job: "checkin", taps: 3, scrolls: 0, chars: 0, alerts: 0,
                                             modelSeconds: 7.8, maxSeconds: 60),
                       "checkin · 3 taps · 0 scrolls · 0 chars · 0 alerts · 7.8 s model · budget 60 s")
        XCTAssertEqual(EaseBudget.resultLine(job: "photo-day", taps: 4, scrolls: 0, chars: 0, alerts: 0,
                                             modelSeconds: 10.4, maxSeconds: 60, note: "+6 s timer"),
                       "photo-day · 4 taps · 0 scrolls · 0 chars · 0 alerts · 10.4 s model · budget 60 s · +6 s timer")
    }

    @MainActor
    func testAFreshBudgetStartsOnOneScreen() {
        let budget = EaseBudget("fresh", maxTaps: 0, maxSeconds: 5)
        XCTAssertEqual(budget.modelSeconds, 1.5, accuracy: 1e-9)
        XCTAssertEqual([budget.taps, budget.scrolls, budget.chars, budget.alerts], [0, 0, 0, 0])
    }
}
