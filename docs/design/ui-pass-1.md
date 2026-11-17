# UI pass 1 · ranked changes for the 18 Nov build

Product Designer → Head of Engineering → iOS Interface Engineer · 17 Nov 2026 · Direction: [`direction.md`](direction.md).

**Two hard rules for every item (QA checks both):** no change adds a required tap or hides Next/Done, and every existing `accessibilityIdentifier` stays exactly as it is. No new dependencies; all APIs are iOS 26 SwiftUI.

Reviewed against main `95a275a`, the M2-05 branch (`claude/project-thread-buqy8y`) and the CI screenshots on `qa/gate-0a-shots`. The baseline is solid: the structure, thumb zone and big numbers are right. What's missing is consistency (Today and onboarding render light while the player is dark, the accent is system blue) and feel (no haptics, numbers jump, no glass).

Sizes: **S** < 30 min, **M** 30–90 min. P1 is the must-ship set (~5 h). P2 makes it feel premium (~3 h). P3 only if time is left.

## P1 · must ship

**UI-1 · One look everywhere (S).** The app is light on Today, onboarding and Sunday prompt, dark only in the player, and the `AccentColor` asset is empty (system blue).
- Set `AccentColor` to system green (Any + Dark), and at the root of `ContentView` add `.preferredColorScheme(.dark)` and `.tint(.go)`.
- Sunday prompt day pills: selected text `Color.onGo` (black), not white (white on green fails 4.5:1).
- Add `App/Design/Theme.swift` with the tokens in `direction.md`.
- Done when: every screen in the UI-test screenshots is dark · Sunday selected pills read black on green · no screen shows system blue as an accent except rest/walk.

**UI-2 · Haptics (S).** None today. Add `.sensoryFeedback` per the table in `direction.md`: Start/Next/Done medium impact, counter `.increase`, last 3 s of rest light impact, rest end and run-walk interval change heavy impact, session done `.success`, zero-alarms warning `.warning` (no haptic on the "alarms were missing, now set" banner).
- Done when: each trigger is bound to a model value change (not a gesture), so voice-driven and auto-advanced changes also fire · no haptic fires on a timer tick other than the last 3 s.

**UI-3 · Numbers roll, in rounded type (S).** Swap every `.system(size:weight:)` numeral (BigNumber, rest clock, dial-to, counter, run-walk clock and label, walk clock, Live Activity clocks) for `Font.coachNumber(size)`. Add `.contentTransition(.numericText(countsDown: true))` on the rest, run-walk and hold clocks and `.numericText()` on the counter, with `.animation(.coach, value:)`.
- Done when: no `.system(size:` literal remains in `App/` or `Shared/` outside `Theme.swift` · with Reduce Motion on, the numbers change without the roll (`@Environment(\.accessibilityReduceMotion)`).

**UI-4 · Today card reads in one glance (S).** The chips stack vertically in a column (screenshot 23 Nov) and the Fine/Sore control is tiny.
- Replace `FlowChips` on the session card with one secondary meta line: "39 min · 9 exercises · Dumbbells, bench, bar".
- Recovery row: label on its own line, then the segmented picker full width with `.controlSize(.large)`; Fine stays pre-selected; keep `today.recovery`.
- Done when: the training-day card is ≤ 4 lines above the recovery row at default text size · both recovery segments are ≥ 44 pt tall.

**UI-5 · Liquid Glass on the chrome only (S).** ✕ buttons (player, run-walk) become `.buttonStyle(.glass)` with `.buttonBorderShape(.circle)` at 44 pt. Secondary buttons (`+30 s`, `Something was different`) use `.buttonStyle(.glass)` with the 50 pt frame; `SecondaryActionStyle` can wrap it. `ActionBar` drops its opaque `systemGroupedBackground` fill so glass sits on the canvas. The primary button stays solid green; cards stay solid.
- Done when: the screenshots show glass ✕ and secondary buttons · primary, cards and numbers are unchanged in contrast · nothing is glass on glass.

**UI-6 · A home for Meals and Progress (M).** Root becomes a `TabView` with three `Tab`s: Today (`sun.max`), Meals (`fork.knife`), Progress (`chart.line.uptrend.xyaxis`). The app always opens on Today; add `.tabBarMinimizeBehavior(.onScrollDown)`. Player, run-walk and walk stay full-screen covers (no tab bar mid-session). Onboarding stays outside the tabs. If M3-04 or M4-03 isn't on main by 18:00, show that tab's `ContentUnavailableView` with one line ("Meals arrive with this week's recipes") rather than an empty screen.
- Done when: launching on any fixture lands on Today · existing Today UI tests pass unchanged · no tab bar shows during a session.

## P2 · makes it feel premium

**UI-7 · Start zooms into the session (S).** `@Namespace` on Today, `.matchedTransitionSource(id: "session", in: ns)` on the Start button, `.navigationTransition(.zoom(sourceID: "session", in: ns))` on the full-screen cover content.
- Done when: Start → player animates from the button; with Reduce Motion it falls back to the standard cover.

**UI-8 · Rest ring with intent (S).** Ring stroke becomes an `AngularGradient` of `rest` to `rest.opacity(0.6)`; the ring and clock stay blue until the last 3 s, then turn `go` green. At 10 s left (the voice heads-up), the "Dial to" weight pulses once (`.symbolEffect`-style scale or `.phaseAnimator`, opacity only under Reduce Motion) instead. Rest clock gets a VoiceOver label ("1 minute 14 seconds left").
- Done when: the mid-rest screenshot shows the gradient ring · the ring is blue at 10 s and green only in the last 3 s · the dial-to weight pulses at 10 s · VoiceOver reads the time in words.

**UI-9 · Done screen feels like a finish (S).** Header gets a 64 pt `checkmark.circle.fill` in green with `.symbolEffect(.bounce, value:)` once on appear and the `.success` haptic. "1 MINUTES" → singular/plural. Where the next session's load goes up, show it in green with `arrow.up` (data from `NextTime`, M2-05 branch); held or reduced loads are neutral grey with no arrow, never red. No confetti, streaks or badges.
- Done when: done screenshot shows the check and correct plural · nothing new needs a tap.

**UI-10 · Run-walk reads from across the room (S).** Full-screen background wash: `go.opacity(0.12)` during jog, `rest.opacity(0.12)` during walk and warm-up/cool-down, animated with `.coach`. Heavy haptic on each change (UI-2).
- Done when: jog and walk screenshots are distinguishable at thumbnail size.

**UI-11 · Lock screen shows the weight to dial (M).** Rest Live Activity lock-screen layout: countdown left (`coachNumber(44)`), a `ProgressView(timerInterval:countsDown:)` bar under it, and on the right "DIAL TO" over the next weight in green (52 pt). Needs the next weight in `RestTimerAttributes.ContentState` (add an optional `nextKg: Double?`; nil hides it). Dynamic Island compact trailing keeps the countdown; minimal shows the countdown in green.
- Done when: the QA-5b mid-rest screenshot shows the bar and the weight · a bodyweight next exercise shows no "DIAL TO".

## P3 · only if time is left

**UI-12b · Today timeline current dot (S).** (Renamed from UI-12; UI-12 is now [Declutter](ui-12-declutter.md).) Current item uses `circle.fill` with `.symbolEffect(.pulse)`; past items stay faded.

**UI-13 · Meals and Progress polish (M).** Build to the screen rules in `direction.md` when M3-04 and M4-03 land: pre-ticked meal rows (unticking triggers nothing), 44 pt aisle ticks, one large lunch suggestion, a Swift Charts hero showing the 7-day average with daily weigh-ins as faint dots, and "Phase 1 · week 3 of 6" over a quieter "Week 3 of about 20".

## Not changing

Layout of the player, the 76 pt primary, ✕ top-left with confirmation, Setup/Move/Fix callouts, the tap counter always visible, no streaks or badges. All agreed in M1 and still right.

## Advisor review

Round 1, 17 Nov. Critique: `/mnt/project-files/advisor/ui-pass-1-critique.md`. Advisor found nothing that adds a required tap; haptics, the tab bar (hidden mid-session) and the done-screen check accepted; lock-screen "Dial to" rated the best item.

| # | Advisor point | Answer | Where |
|---|---|---|---|
| 1 | Progress shows "Phase 1 · week 3 of 6" plus a quieter "Week 3 of about 20"; "of 6" alone reads as a finish line | **Accepted** | direction.md Progress, UI-13 |
| 2 | Weight chart hero is the 7-day average; daily weigh-ins faint dots, never the big number | **Accepted** | direction.md Progress, UI-13 |
| 3 | Rest ring blue until the last 3 s, not 10 s (green at 10 s invites starting early); pulse the "Dial to" weight at 10 s instead | **Accepted** | UI-8 |
| 4 | Lifts table: no red, no down arrows; held or reduced loads neutral grey | **Accepted** | direction.md Progress, UI-9 |
| 5 | No `.warning` haptic on the "missing, now set" banner; keep it for zero alarms | **Accepted** | haptics table, UI-2 |
| 6 | Condition: unticking a meal triggers nothing | **Accepted** | direction.md Meals, UI-13 |
| 7 | Condition: Today stays the daily home; Meals tab never needed on a normal day | **Accepted** (already the rule: meals show as Today timeline rows) | direction.md Today, UI-6 |

All points accepted, so no round 2. Open taste decisions for Gate 2 are unchanged (see direction.md).
