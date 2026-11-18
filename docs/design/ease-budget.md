# Ease budget · taps and time for every job

Product Designer · 18 Nov 2026 · Board N9 (wave 2). Gap plan: [`../review/gap-analysis-and-build-plan.md`](../review/gap-analysis-and-build-plan.md) §4.5 and §5. Measured with QA's method: [`../qa/ease-budget-method.md`](../qa/ease-budget-method.md) (the `EaseBudget` helper and its fixed time model). Where this file and QA's table differ, **this file sets the budget and QA's method measures it.**

Still in force: [`direction.md`](direction.md), [`ui-pass-1.md`](ui-pass-1.md) and the six rules of [`ui-12-declutter.md`](ui-12-declutter.md). Every new screen below follows them: one primary, at most five things above the fold, say it once, nothing uninvited, secondary one tap away, targets 44 pt or more.

**Guiding rule:** if it takes thinking or admin time, it has failed. "Easy" here means a number a test can fail.

## 1. Rules every budget test checks

Each rule is checked inside `EaseBudget`, so a job can't pass by being clever.

| # | Rule | How the test checks it |
|---|---|---|
| E1 | **Taps** never exceed the job's budget, on the default path and on the "change one answer" path | `finish` asserts `taps <= maxTaps` (QA method) |
| E2 | **Time** (model seconds) never exceeds the job's budget | `finish` asserts `modelSeconds <= maxSeconds` (QA method; 1.1 s a tap, 1.5 s a screen, 1.0 s a scroll, 0.3 s a character, 2.0 s an alert) |
| E3 | **No scrolling** in any job marked daily or weekly. A control you have to scroll to is a design bug, not a slow job | Helper: `maxScrolls: Int = 0`, asserted in `finish`; a control not hittable when tapped fails as "needs a scroll", so XCUITest's auto-scroll can't hide one. A1 sets `maxScrolls: 2` |
| E4 | **No typing** in daily or weekly jobs. Only Preferences numbers take characters; the optional waist uses a stepper (Advisor 5) | Helper: `maxChars: Int = 0`, asserted in `finish`; also `app.keyboards.count == 0` at `finish`. Only A1 sets `maxChars` (the waist stepper needs none) |
| E5 | **No confirmation alerts.** The only "are you sure?" in the app is ending a session early. System permission alerts are allowed once, and counted | Helper: `maxAlerts: Int = 0`, asserted in `finish`. W3's first run sets 1, A4 sets 2 |
| E6 | **Every tapped control is at least 44 × 44 pt** | Helper: `tap` asserts the accessibility frame is at least 44 × 44. Fix a small control by padding inside its label, not with `.contentShape` or an exception. System UI (alerts, share sheet, Reminders permission, notifications) uses `tap(_:system: true)`: counted, size not checked |

QA accepted E3–E6 into the helper on PR #93; `docs/qa/ease-budget-method.md` holds the helper spec.

**Notification starts** (W1, W5, F1, K3): tests launch with `-openFrom notification:<kind>`, which routes the app exactly as the notification would, then count the notification tap once with `budget.tap(…, system: true)`. Each route gets one unit test; QA checks the route matches in QA-R4.

A tap on a notification counts (QA method). The first-ever run of a job (permission alerts, the one-off shop question) has its own row, so the everyday row stays strict.

## 2. The budgets

Default path = the CEO accepts every pre-selected answer. Change path = he changes one thing, the most likely one. **Taps** and **Time** are the numbers the test asserts. The model time in brackets is today's design, so the headroom is visible.

### Daily

| ID | Job | Start → done state (identifier) | Taps default / change | Time | Notes |
|---|---|---|---|---|---|
| D1 | See what's next | Launch → `today.title` visible, Today selected | 0 | 5 s (1.5) | No scroll to see title, card and Start |
| D2 | **Start today's session** | Launch → player on set 1 (`player.done`) | **1** / 2 | 10 s (4.1) | Change = "Still sore" first (`today.recovery`) |
| D3 | Do a set as prescribed | Set screen → next set screen | 2 per set (Done, Next) | — | Whole session: `2 × sets + 1`; nothing else (existing test, now through the helper) |
| D4 | Log "something was different" | Done screen → edit saved (`edit.save`) | 3 | 15 s | One value changed |
| D5 | Run-walk | Launch → `run.doneTitle` | 2 (Start, Finish) | — | 0 taps during the run; clock injected |
| D6 | **Change a meal** (skipped it) | Launch → meal shows Not eaten (`meals.tick.*`) | **2** | 10 s (5.2) | Unticking triggers nothing (no prompt) |
| D7 | Eating out (C4) | Launch → dinner replaced, counter "1 of 2" | 2 | 10 s | One visible button on the dinner row; no swipe |
| D8 | See today's office lunch order | Launch → lunch row on Today | **0** | 5 s | Today timeline row on office days (direction.md, Advisor condition) |
| D9 | Another lunch order | Launch → new suggestion | 2 | 10 s | Lunch row → `lunch.another` |
| D10 | See a coach line (C2 stall, N8 "Easing back in", N2 change) | Launch → line on Today | 0 / 1 to open | 5 s | One line, never more than one on Today |
| D11 | Weigh in, wake up, weather swap | — | 0 | — | Scale via Health, system alarm, swap is automatic; "Run anyway" is 1 |
| D12 | Easing back in after a break (N8) | Launch → player opens at eased loads, one line says why (`player.easing`) | 0 extra (Start only) | — | No question asked; the line reads "Easing back in after 12 days off" (Advisor) |
| D13 | Social-meal rebalance (C4) | — | 0 | — | Never shown as a task or a number to manage; the week rebalances silently inside the floors (Advisor) |

### Weekly

| ID | Job | Start → done state | Taps default / change | Time | Notes |
|---|---|---|---|---|---|
| W1 | **Sunday check-in** (N1, includes office days) | Check-in card or notification → Today with the week applied (`checkin.applied`) | **3** / 8 | **60 s** (7.8 / 13.3) | Change = 2 office days, energy Low, pain Yes plus area |
| W2 | **Find the shopping list** | Launch → `shopping.header` | **1** | 5 s (4.1) | Needs the Shopping tab (§4, F2) |
| W3 | Send the list to Reminders (N5) | Launch → `shopping.sent` | 2 | 10 s | First time: plus one system alert (allowed, counted) |
| W4 | Shop in store (N5) | Launch → in-store mode, 5 items ticked | 2 + 1 per item | 20 s for 5 items | Ticked items leave; the next item is always on screen: **0 scrolls** |
| W5 | Delivery-slot reminder (N5) | Notification → Shopping | 1 | 5 s | |
| W6 | Read what changed (N2) | Launch → `changes.card` on Progress | 1 | 5 s | Also shown inside W1 at 0 extra taps |

### Fortnightly, checkpoints and rare

| ID | Job | Start → done state | Taps default / change | Time | Notes |
|---|---|---|---|---|---|
| F1 | **Photo day** (N7) | Notification → both poses saved, Progress shows them | **4** / 6 | **60 s** (10.4) | Waist on: a stepper pre-filled with the last value, 0.5 cm steps, usually 1–2 taps; typing is the fallback (Advisor 5). The two 3 s self-timers sit outside the model: the result line records "+6 s timer" (QA). The model doesn't count the seconds spent stepping into pose; the 3 s self-timer and hints cover that, and 60 s leaves room |
| F1b | Photo day without the notification | Launch → same | 5 | 60 s | Progress → photo-day card |
| F2 | Compare photos (N7) | Launch → `compare.view` today vs week 0 | 2 / 3 | 10 s | Change = "4 weeks ago" |
| K1 | Ask the coach now | Launch → share sheet open with the summary | 2 | 10 s | Picking Claude in the share sheet is the system's |
| K2 | Import Claude's reply | Launch → `coach.import.result` | 2 | 10 s | Reads the clipboard; no paste step |
| K3 | Checkpoint due (N10) | Notification → Progress with Ask the coach | 1 | 5 s | |
| A1 | Change a preference (N3) | Launch → value changed, "From tomorrow" shown | 4 | 20 s | 2 scrolls allowed in the module list only; numbers ≤ 6 chars |
| A2 | First shopping list (N4, once) | Launch → `shopping.header` | 2 / 4 | 15 s | Defaults Waitrose and Sunday; change = shop and slot |
| A3 | First office day (N4, once) | Launch → lunch suggestion | 1 / 3 | 10 s | Skipping is 0 taps: defaults apply |
| A4 | Onboarding | New install → Today | 3 + 2 alerts | 5 min | Existing flow, now through the helper |

## 3. New screens (N1–N7)

Each screen follows the UI-12 rules. New identifiers are listed so the tests above can be written before the screens land. Existing identifiers keep their names.

### N1 · Sunday check-in (replaces the Sunday prompt)

Two screens, no scrolling. The card on Today reads "Check in · 1 min ›" (`today.checkIn`, keeps the weekend slot of `today.planWeek`).

**Screen 1 · "Your week"** (`checkin.week`): ① weight hero, "82.4 kg · −1.1 kg since start" (7-day average; never week on week, which is mostly water; Advisor 1) ② one line, "4 of 4 sessions · 8,900 steps a day", information only: no ring, target or colour (Advisor 6) ③ Energy: Good · OK · Low (`checkin.energy`) ④ Sleep: Fine · Poor (`checkin.sleep`) ⑤ Any pain: None · Yes (`checkin.pain`). Each pill and pain area is at least 44 pt wide and tall: full-width segmented controls at `.controlSize(.large)` (E6, QA). Primary **Next** (`checkin.next`). Defaults Good, Fine, None (Advisor A1). Pain Yes reveals the areas in place, two rows of three: Shoulder, Elbow, Wrist, Back, Knee, Other (`checkin.painArea.*`); no typing; nothing else moves. The pick swaps that area's exercises to their catalogue `swap` for 7 days, adds a What-changed line, and isn't asked again that week (Advisor 2). Energy Low **and** Sleep Poor together are one low-recovery signal for the existing drop-to-2 rule; either alone is noted for the Claude summary and changes nothing (Advisor 3).

**Screen 2 · "Next week"** (`checkin.plan`): ① office day pills, pre-filled from last week (`sunday.day.*`, unchanged ids) ② "Early start or late finish?" folded (`sunday.times`) ③ What changed, at most 4 lines (`changes.card`, N2) ④ the week's sessions in one line. Primary **Looks good** (`checkin.done`). Back returns to screen 1 without losing answers.

Skipping: the card stays until Monday, then goes. The plan runs unchanged (N1 Done-when). No reminder nags beyond the one check-in notification.

### N2 · What changed and why

One card (`changes.card`), one line per change (`changes.line.*`), at most 4, then "N more ›". Format: **what, old → new: why**, under 10 words, e.g. "Calories 2,000 → 1,900: loss slowed over 2 weeks"; a calorie line always gives the 2-week reason (Advisor 4). Load rises green ↑; held or eased loads grey, never red (direction.md). Shown in check-in screen 2 and at the top of Progress for 7 days after a change. No card when nothing changed.

### N3 · Settings → Preferences

`today.more` → **Settings** (`today.settings`) → a list of modules A–J (`prefs.module.*`), each showing its current value as the subtitle. A module opens a standard form; changes save as you make them, with no Save button and no confirmation. One footer line: "Changes start tomorrow." (`prefs.fromTomorrow`). Dislikes (Advisor A4f) are picked from a list of common ingredients with search, not typed from scratch. The check-in day and time live here.

### N4 · Ask when needed

**Shop** (first visit to Shopping, once): one sheet (`ask.shop`), two pre-selected choices: shop (Waitrose · Ocado · M&S · Tesco · Sainsbury's) and delivery slot (Sunday morning). Primary **Use these** (`ask.shop.done`). **Office food** (first office day, once): inside the lunch suggestion, one line "Walk up to 10 min · no dislikes" with **Looks right** (`ask.lunch.done`). Ignoring it uses the defaults. Both editable in Preferences.

### N5 · Grocery

Shopping (now its own tab, §4) gets one action bar: primary **In the shop** (`shopping.inStore`), secondary **Send to Reminders** (`shopping.reminders`). After sending, the header line reads "Sent to Reminders · Shopping" (`shopping.sent`) for the rest of the day. In-store mode (`instore.view`): unticked items only, aisle order, rows 64 pt, the shop's search links hidden, screen kept awake, ✕ top-left. "All done" (`instore.done`) when the list is empty.

### N6 · Recipe variety

No new screen. The budget it must keep: a recipe still opens in one tap from its meal row (D6 path plus 1).

### N7 · Photos

**Photo day** (`photo.view`), full-screen camera: ① ghost outline of the first photo of this pose (`photo.ghost`) ② one hint line, four words at most, "Step back a little" (`photo.hint`), or nothing when the pose is right ③ "Front · 1 of 2" ④ shutter, primary (`photo.take.front`, `photo.take.side`, unchanged). The shutter starts a 3 s self-timer with a tick haptic and sound, so the phone can sit on a shelf. Then one review screen: both shots side by side, the waist row only if turned on (`photo.waist`): a stepper pre-filled with the last value in 0.5 cm steps, with one line "At the navel, after breathing out"; primary **Save** (`photo.save`).

**Compare** (`compare.view`): Progress → "Photos · next Mon 7 Dec ›" (`progress.photos`) opens straight onto today against week 0, with a slider (`compare.slider`) and a two-way switch, Week 0 · 4 weeks ago (`compare.against`). Weight trend and waist (when on) sit under the photos as one line.

## 4. Walk of `main` against the budget (ccb22ed, 18 Nov)

Counted from the code and the UI tests on `main`. These are the fixes the budget needs; the iOS Interface Engineer owns them unless stated.

| Job | Now | Budget | Status | Fix |
|---|---|---|---|---|
| D2 Start session | 1 | 1 | ✅ | — |
| D3 Sets | Done, Next | same | ✅ | Route the existing test through the helper |
| D6 Change a meal | 2 | 2 | ✅ | — |
| D8 Office lunch order | 2 (Meals, Lunch) | 0 | ❌ | **F1:** lunch row on Today's timeline on office days ("12:30 Lunch · Chicken salad, Pret"); tapping it opens the lunch card. Planner adds the timeline item (`TimelineItem.kind .lunch`) |
| W1 Sunday check-in | Sunday prompt only, 2 taps; no check-in | 3, 60 s | ❌ | N1 |
| W2 Shopping list | 2 (Meals, Shopping segment) | 1 | ❌ | **F2:** Shopping becomes a fourth tab (Today · Meals · Shopping · Progress, `cart`); Meals keeps Meals and Lunch. Always one tap, every day, with no hidden "last used" memory. Same ids; `MealsUITests` taps the tab instead of the segment |
| F1 Photo day | 5 from launch, no notification | 4 | ❌ | N7 notification opens the camera directly |
| K1 Ask the coach | 2 | 2 | ✅ | — |
| K2 Import | 2 | 2 | ✅ | — |
| A1 Preferences | impossible | 4 | ❌ | N3 |
| App icon | M0-02 placeholder | finished icon | ❌ | §5 |

Nothing on `main` breaks E3 to E6 that I could find in the code; the tests will confirm it.

## 5. App icon

The current icon is the M0-02 placeholder (white dumbbell on teal; it doesn't match the black and green of the app).

**Default (a taste decision, batched for the CEO, not asked):** a bold system-green dumbbell, tilted 30° upward, on black. It reads as "training", the upward tilt reads as "progress", and it uses only the app's two colours. Concept at [`icon/app-icon-1024.png`](icon/app-icon-1024.png), with 180, 60 and 40 px previews in [`icon/app-icon-preview.png`](icon/app-icon-preview.png).

Build: an Icon Composer `.icon` with two layers (black background, green glyph), so iOS 26's Default, Dark, Clear and Tinted looks come for free. No text, no SF Symbols (Apple's licence rules them out in icons), no gradient.

**Done when:**
- The app's icon is not the placeholder: a CI check fails if `AppIcon.png` still has SHA-256 `7866d597…a603`.
- The four iOS 26 appearances are attached to the PR as PNGs from Icon Composer.
- At 40 px the dumbbell still reads as a dumbbell (QA, by eye from the preview).

## 6. Done when (this spec, N9)

- Every job in §2 has a UI test through `EaseBudget` that asserts its taps, time, scrolls and characters; the five gap-plan jobs (D2, D6, W1, W2, F1) land first.
- Every ❌ in §4 is fixed, or written into §7 with a reason the round can accept.
- QA-R4 attaches each job's result line and `ease-<job>` shot.
- The app icon meets §5.

## 7. Over budget, with reasons

Empty. Anything that can't meet its budget by 18:00 on 19 Nov goes here with its reason, and the Head of Engineering decides whether it ships.

## 8. Advisor review

Round 1, 18 Nov. Critique: `/mnt/project-files/advisor/n9-ease-budget-critique.md`. Verdict: signed off once points 1–3 are in; admin check passes.

| # | Advisor point | Answer | Where |
|---|---|---|---|
| 1 | Check-in weight hero is the 7-day average with change since start (or over 2 weeks), never week on week | **Accepted**: "since start", matching the Progress hero | §3 N1 |
| 2 | Pain Yes: one area row (Knee, Shoulder, Back, Other), no typing, 7-day swaps, What-changed line, not asked again that week | **Changed**: all accepted except the list. It keeps the six areas from your A1 answer (Shoulder, Elbow, Wrist, Back, Knee, Other), which are in the merged N1 Done-when that QA tests, laid out as two rows of three | §3 N1 |
| 3 | Energy Low plus Sleep Poor = one low-recovery signal for the drop rule; one alone changes nothing | **Accepted** (same as N1 Done-when) | §3 N1 |
| 4 | N2 wording and 7 days on Progress; calorie lines give the 2-week reason; eased loads grey | **Accepted** | §3 N2 |
| 5 | Waist: stepper pre-filled, 0.5 cm steps, typing as fallback; one-line measuring rule | **Accepted** | E4, F1, §3 N7 |
| 6 | Steps information only, no ring or target colour | **Accepted** | §3 N1 |
| — | Lunch row on Today, office days only | **Accepted** (already the fix) | §4 |
| — | Shopping tab; "In the shop" as primary | **Accepted** | §4, §3 N5 |
| — | Add D12 Easing back in: 10+ days off, N8 bands (90/80/70%), 0 taps, one line | **Accepted** | §2 D12 |
| — | Social-meal rebalance stays invisible, 0 taps | **Accepted** | §2 D13 |
| — | Cut nothing | **Accepted** | |

## 9. Open taste decisions (for the CEO's pack, not asked)

1. App icon: green dumbbell on black (default) or another mark.
2. Shopping as its own tab (default) or the Meals tab opening on Shopping on shop day.
3. In-store mode as the Shopping primary (default) or Send to Reminders as the primary.
4. Still open: accent colour, always dark, rounded numerals (`direction.md`), and the three in `ui-12-declutter.md`.
