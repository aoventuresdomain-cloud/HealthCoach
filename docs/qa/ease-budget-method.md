# Ease budget: how the UI tests measure it (N9, QA's part)

**Owners:** Product Designer (the budgets, in `docs/design/ease-budget.md`), iOS Interface Engineer (the tests and fixes), Head of QA (this method, and timing in QA-R4).
**Source:** `docs/review/gap-analysis-and-build-plan.md` §4.5 and §5 N9.

A simulator test can't feel how long a job takes a person. So each job's test checks two things: a **tap count** that is exact, and a **time** estimated from those taps with a fixed, published model. That makes the numbers repeatable from run to run, and argued about once, here.

## 1. What counts as a tap

- **Counts as one tap:** a tap, a toggle, choosing from a picker, a swipe that does something (deleting a row, for example), and answering a system alert.
- **Counts as one interaction:** a scroll needed to reach a control. It counts towards the time model but not the tap count. If a control is only reachable by scrolling, that's recorded in the result.
- **Typing:** focusing a field is one tap. Each character typed costs time (§3) but adds no taps.
- **Start point:** the app has just launched to the default screen (Today), unless the job says otherwise. A notification-started job (photo day, check-in) starts from tapping the notification. That tap counts.
- **End point:** the screen shows the job's done state, and the test asserts that state by its identifier, not by waiting.
- **Defaults are accepted, not changed.** The budget is for the common case: the CEO taking the pre-selected answers. One test per job also does the "change one answer" path, and must still stay within budget.

## 2. The helper

Every budget test goes through one helper in `HealthCoachUITests/EaseBudget.swift`, so no test can tap around the counter:

```swift
/// Counts the person's interactions for one daily job and checks them against its budget.
@MainActor
final class EaseBudget {
    let job: String; let maxTaps: Int; let maxSeconds: Double
    private(set) var taps = 0, scrolls = 0, chars = 0, screens = 1
    init(_ job: String, maxTaps: Int, maxSeconds: Double) { … }

    func tap(_ e: XCUIElement, newScreen: Bool = false)   // asserts e is hittable first; taps += 1
    func type(_ e: XCUIElement, _ text: String)           // taps += 1 (focus), chars += text.count
    func scroll(_ e: XCUIElement, to target: XCUIElement) // scrolls += 1 per swipe until hittable
    var modelSeconds: Double { … }                        // §3
    func finish(done: XCUIElement, file: StaticString = #filePath, line: UInt = #line)
        // asserts done.exists, taps <= maxTaps, modelSeconds <= maxSeconds,
        // and attaches a one-line result: "checkin · 7 taps · 0 scrolls · 41.2 s model · budget 60 s"
}
```

- Tests never call `.tap()` directly between `EaseBudget.init` and `finish`. QA greps for this in review.
- `finish` attaches a screenshot of the done state, named `ease-<job>`, so the round reads it with the other shots.

## 3. Time model (keystroke-level, fixed)

| Action | Seconds | Why |
|---|---|---|
| Tap (point and tap) | 1.1 | Fitts-style pointing plus the press, on a phone held in one hand |
| New screen read (each `newScreen: true`, and the first screen) | 1.5 | Finding the next control on an unfamiliar screen |
| Scroll | 1.0 | One swipe and re-orient |
| Character typed | 0.3 | Average phone typing speed |
| System alert | 2.0 | Reading it and choosing |

`modelSeconds = 1.1·taps + 1.5·screens + 1.0·scrolls + 0.3·chars + 2.0·alerts`

These numbers are deliberately a little slow, so a pass means the job is comfortably inside its budget. The real simulator run time is also recorded, but only as a sanity check. If it is ever more than three times the model, QA looks for a slow screen.

## 4. The jobs and budgets (from §4.5; the Designer's file wins if it differs)

| Job | Start | Done state | Taps | Time |
|---|---|---|---|---|
| Start today's session | Launch to Today | Player on set 1 | 1 | — |
| Tick off a meal change | Launch to Today | Meals shows the swapped meal ticked | 2 | — |
| Sunday check-in | Check-in card (or notification) | "Looks good" applied, Today back | — | 60 s |
| Photo day | Photo-day card (or notification) | All poses saved, Progress shows them | — | 60 s |
| Find the shopping list | Launch to Today | Shopping list visible | 1 | — |

Where the plan sets only a time, QA still reports the tap count. Where it sets only taps, QA still reports the model time. This keeps a later change from quietly making a job slower.

## 5. In QA-R4

- Every job's test passes on the round SHA, and its result line and shot are in the round record.
- A job over budget is either fixed or recorded in `ease-budget.md` with a reason. A reason the round can accept is a system screen we don't control, such as the Reminders permission alert.
- On top of that, QA walks each job by hand from the shots. A job that passes the count but needs a hidden gesture, an unlabelled icon, or a scroll the person wouldn't expect is a minor finding, even though the test is green.
