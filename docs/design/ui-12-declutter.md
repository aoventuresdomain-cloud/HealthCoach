# UI-12 · Declutter

Product Designer · 17 Nov 2026 · Round 1. Asked by the CEO at 21:08 UTC: *"Change the ui and simplify, it's too crowded, as I said before. Apply best practices."* This is the second time they have asked, so this pass **cuts and moves things; it does not restyle them**. Colour, type, tokens and components stay as set in [`direction.md`](direction.md). The [`m1/README.md`](m1/README.md) and [`ui-pass-1.md`](ui-pass-1.md) rules still hold unless this file changes them.

**Before shots:** `qa/gate-0a-shots` at `375c226` (built from `b59f62d`), in `screenshots/ui-tests/`. They are named here by their test attachment name, for example `week1-monday` is `testClockAndFixtureAreInjected-week1-monday_0_….png`.

> Naming: the old P3 item in `ui-pass-1.md` ("Today timeline current dot") is renamed **UI-12b** (Head of Engineering, 17 Nov). This file is **UI-12 Declutter**.

## The rules for every screen

1. **One primary action** (the 76 pt green button) and at most one secondary. There are no other buttons in the content.
2. **At most five things above the fold** (counted at default text size on a 6.3" phone). A card counts as one thing; a list counts as one thing.
3. **Say it once.** If the title already says it, the card doesn't repeat it. If the tab bar says "Meals", the nav bar doesn't.
4. **Nothing that needs no action shows up uninvited.** Reassurance banners, empty states for things that haven't happened yet, and helper copy that explains the obvious are all cut.
5. **Secondary information is one tap away**, in a disclosure row, a detail screen or the ⋯ menu. Nothing is deleted from the app; it moves.
6. Targets stay ≥ 44 pt. In normal use the taps are still only Start, Next, Done and the Sunday prompt. **Every existing `accessibilityIdentifier` keeps its name**; where an element moves, the "Test impact" section lists the tests that need one extra tap.

Apple HIG basis: *Layout* (prioritise essential content and defer secondary content), *Disclosure controls* (progressive disclosure), *Writing* (cut words that don't help), *Toolbars* (put extra actions in a ⋯ menu instead of crowding the bar).

---

## 1. Today

**Before:** `week1-monday`, `today-weather-swap`, `a7-wednesday-rest`, `a1-week-planned`, `today-no-alarms-warning`. On a training day there are **11 things** above the fold: calendar icon, wrench icon, date line, title, test status line, the "N alarms were missing" banner, weight line, card (name, muscles, meta line, sore question and picker), timeline, Start and the tab bar.

| Element (id) | Decision | Why |
|---|---|---|
| `today.title` "Upper A at 08:05" | **Keep** | It is the answer to "what now?" |
| `today.date` | **Keep, shorter:** "Mon 23 Nov · Week 1" | The phase is on Progress; capitals cut |
| `today.start` | **Keep** (primary) | |
| `today.timeline.*` | **Keep**, but subtitles only where they add something | "Alarm" under Wake and "Done by 08:44" under the session repeat what you can already see. Keep "Lights out 23:30 for a 08:00 alarm" and "25 min" on Leave |
| `today.recovery` Fine / Sore picker | **Keep**, without the label line. The segments read **"Fine" / "Still sore"**, and VoiceOver still reads the full question | The Advisor needs the signal; the label line was a duplicate |
| `today.card` | **Cut the card's title and muscle line** ("Upper A" / "Chest, back, shoulders, arms, core"). The card becomes the meta line plus the picker | The title already names the session. The player shows the muscles |
| `today.card` on a no-session day ("No session today · Counts as conditioning…") | **Cut the card**; the title and timeline say it | Say it once |
| "N alarms were missing. They're set again" banner (`today.alarmBanner`) | **Cut**. It shows on almost every launch and needs nothing | Rule 4. Advisor point 5 already called it reassurance |
| `today.alarmWarning` (no alarms set, with `today.openSettings`) and "Alarm check failed" | **Keep** | These need the owner |
| `today.weight` "82.7 kg (7-day average), down 0.7 kg on last week" | **Move to Progress** (it is already `progress.weight` there) | It is not today's action, and a daily number on Today invites checking |
| Calendar icon `today.planWeekToolbar` + wrench `home.spikeTests` | **Move into one ⋯ menu**, top-right, new id `today.more`. It holds Plan week (`today.planWeekToolbar`), Tomorrow changed (M2-06) and, in debug and spike modes only, Spike tests (`home.spikeTests`, per M0-11b) | Two chrome icons become one, and M2-06 gets a home without adding a third. **This supersedes #72's "Tomorrow changed" secondary button on Today**; the iOS engineer builds it as a menu item instead (Head of Engineering, 17 Nov) |
| `today.planWeek` card (weekend, when due) | **Keep, one line:** "Plan next week · 20 s ›" | It is the one admin task of the week; it must stay visible when due |
| `today.weatherSwap` card | **Shrink to the card's meta line:** "28 min · rain swapped your run". `today.runAnyway` becomes the **secondary button** above Start | One card fewer; "Run anyway" is an action, so it belongs in the action bar |
| `debug.launch` test status line | **Keep for tests, invisible in shots:** 1 pt tall, clipped, `.accessibilityHidden(false)` so XCUITest still reads its label | It makes every review shot look like a debug build |
| Tab bar | **Keep** | |

**After (training day), above the fold:** ① date line ② title ③ card: meta line plus Fine / Still sore ④ timeline ⑤ Start. The ⋯ menu and the tab bar are chrome.

```
 Mon 23 Nov · Week 1                       ⋯
 Upper A at 08:05
┌──────────────────────────────────────────┐
│ 39 min · 9 exercises · Dumbbells, bench  │
│ [   Fine   |  Still sore  ]              │
└──────────────────────────────────────────┘
┌──────────────────────────────────────────┐
│ 07:50 ● Wake                             │
│ 08:05 ○ Upper A                          │
│ 08:55 ○ Leave · 25 min                   │
│ 23:00 ○ Wind down · lights out 23:30     │
└──────────────────────────────────────────┘
 [ Start Upper A                          ]
        Today    Meals    Progress
```

On a rain day the card reads "28 min · rain swapped your run", with **[ I'll run anyway ]** (secondary) above **[ Start Indoor circuit ]**. On a rest day there is no card, only the title, the timeline and "See tomorrow".

## 2. Workout player: a set

**Before:** there is no set-screen shot in the CI set (QA, please add one). The reference is `m1/png/player-set.png`, built as M1-06. Above the fold there are 7 things: progress bar, GIF, name, numbers row, the "stop with N left" line, three callouts, the counter and Done.

| Element (id) | Decision | Why |
|---|---|---|
| `player.media`, `player.exerciseName`, numbers row, `player.done`, `player.counter` | **Keep** | They are the set |
| `player.callouts` (Setup / Move / Fix) | **Show all three on the first set of each exercise; from set 2 show only Fix.** Tapping the line expands the other two | You need the setup once. After that the one cue that matters is the fix. It is still visible with no tap (Advisor B5) |
| "Stop with N left in the tank" line | **Merge into the Reps caption:** "REPS · 3 in reserve" | One line fewer |
| `player.dumbbellLimit`, `player.slowTempo` | **Keep, only when true** (no change) | |
| `player.progress` with its "Warm-up / 3 / 9" label | **Keep the bar, cut the label** | The bar already shows position |

**After:** ① GIF ② name ③ numbers ④ Fix callout (all three on set 1) ⑤ counter plus Done.

## 3. Workout player: rest

**Before:** `player-rest`, which shows 6 things: ring with "REST" and "of 1:15", the next card, the "Voice says 3, 2, 1, go…" helper, +30 s and Next.

| Element | Decision | Why |
|---|---|---|
| `player.restClock` ring | **Keep; cut "of 1:15"** | The ring shows the proportion |
| "REST" label in the ring | **Keep** | It reads from across the room, and the colour alone isn't accessible |
| Next card with `player.restThumbnail`, name, set line and `player.dialTo` | **Keep** | It is the most useful thing on the screen (Advisor) |
| Voice helper line | **Cut** | Explains the obvious after the first rest |
| `player.extendRest` (+30 s) and `player.next` | **Keep** | |

**After:** ① ring ② next card ③ +30 s ④ Next.

## 4. Workout player: done

**Before:** `player-done`, which shows check, title, "1 MINUTE · 18 SETS", nine rows of what was just done, "NEXT TIME" below the fold, `player.edit` and Done.

| Element (id) | Decision | Why |
|---|---|---|
| Check and `player.doneTitle` | **Keep** | |
| Stats | **One line:** "39 min · 18 sets · logged as prescribed" | Two big numbers for a summary nobody acts on |
| The list of what was done (nine rows) | **Move behind `player.edit`** ("Something was different"); the edit screen lists the sets anyway | You just did it. It is a duplicate of the log |
| `player.nextTime.*` | **Bring above the fold. Show only lifts whose load goes up** (green ↑), then one grey line, "7 others the same" | It is the only new information on the screen. Rule from the Advisor: no red, no down arrows |
| `player.edit` and `player.finish` | **Keep** | |

**After:** ① check and title ② one stats line ③ Next time (changes only) ④ Something was different ⑤ Done.

## 5. Run-walk and walk

**Before:** `run-walk-week1` and `a11-sunday-walk`. The run-walk screen shows ✕, "Run-walk · Week 1", "Voice on", a "WARM-UP" eyebrow, "WARM-UP WALK", the clock, "Then jog 1:00", "Easy pace: you could chat", the segment bar with three labels, the stats line and Pause.

| Element (id) | Decision | Why |
|---|---|---|
| `run.label`, `run.clock`, `run.pause`, segment bar | **Keep** | |
| Title "Run-walk · Week 1" | **Cut**; `run.end` ✕ stays | You started it from Today |
| "Voice on" | **Cut**; show "Voice off" only when it is off | Only the exception needs saying |
| "WARM-UP" eyebrow above "WARM-UP WALK" | **Cut** | Duplicate |
| "Then jog 1:00" | **Keep** | |
| "Easy pace: you could chat" | **Show only during the warm-up and the first jog**; the voice says it too | Advisor round 1 point 8 asked for it once, not on every interval |
| Segment bar labels (Warm-up walk / 10 × jog, walk / Cool-down) | **Cut** | Colour and length show it |
| `run.stats` "0:03 gone · 27:57 to go" | **Show "27:57 to go" only.** Time gone and distance move to the done screen | |
| Walk screen (`walk.title`) | **Same rules**: clock, "to go", Finish | |

**After:** ① label ② clock ③ then-line ④ bar plus "to go" ⑤ Pause.

## 6. Meals

**Before:** `meals-today`, which shows the nav title "Meals", tabs (Meals / Shopping / Lunch), the "‹ Today ›" stepper, the totals card (1,930 kcal of 2,000 · 161 g protein of 160), four meal rows each with a category, name, kcal/protein line, chevron and tick, the supplements line, and a footer helper.

| Element (id) | Decision | Why |
|---|---|---|
| Nav title "Meals" | **Cut**; `meals.tabs` is the header | The tab bar already says Meals |
| `meals.day` stepper with `meals.previousDay` / `meals.nextDay` | **Move into the nav bar:** "Today" as the title, ‹ › as toolbar buttons | Frees a whole row |
| `meals.totals` card | **Shrink to one secondary line under the tabs:** "1,930 kcal · 161 g protein" with no "of 2,000" targets | The engine steers by the scale. A target next to a total invites tracking, which the plan said to avoid |
| `meals.row.*` | **Keep the category and name; cut the kcal/protein line** (it moves to `recipe.view`) | Four rows become half the height |
| `meals.tick.*` | **Keep** (pre-ticked; unticking triggers nothing) | |
| Supplements line | **Keep** | It is the only place they appear |
| Footer "Planned meals count as eaten. Untick anything you skipped." | **Show once, until the first untick**, then never again | Needed once, obvious after |

**After:** ① tabs ② totals line ③ meal list (4 rows) ④ supplements line. There is no primary button, because there is nothing to do.

## 7. Recipe

**Before:** `recipe`. It is already lean. **Keep** everything; the meta pill becomes plain secondary text ("10 min · makes 2 · 480 kcal, 41 g protein each"). No other change.

## 8. Shopping

**Before:** `shopping`, where every row carries a large green "🔍 Waitrose" button. That is nine identical buttons above the fold, and the biggest single source of clutter in the app.

| Element (id) | Decision | Why |
|---|---|---|
| `shopping.tick.*` (44 pt) and `shopping.row.*` (name and quantity) | **Keep** | |
| `shopping.search.*` | **Becomes a quiet 44 pt magnifier icon at the trailing edge** (secondary colour, no label). The shop name appears once, in the header | Same function, a ninth of the noise |
| Aisle headers | **Keep** | |
| Header | **New line under the tabs:** "Waitrose · 23 to get" | It names the shop once and gives a count that shrinks as you tick |

**After:** ① tabs ② header line ③ aisle-grouped list.

## 9. Lunch

**Before:** `lunch`, which shows an explanation ("Today isn't an office day…") over six long rows, each with the place, walk, kcal, protein and price.

| Element (id) | Decision | Why |
|---|---|---|
| **Office day** | **One suggestion card, large:** the order name, then "Pret · 5 min · 61 g protein". **"Another"** is the secondary button. The full list sits behind "All 6 orders ›" | Per `direction.md`: one order, large |
| **Other days** | **One line:** "No office today." The list stays behind "All 6 orders ›" | Nothing to do |
| `lunch.row.*` | **Two lines:** the order name, then "Pret · 5 min · 61 g". kcal and price move to `lunch.detail` | Rows half the height |

**After (office day):** ① tabs ② suggestion card ③ Another ④ All 6 orders.

## 10. Progress

**Before:** `progress-after-photos`, which shows the big title, "Weight" header, a card with the phase line, chart and average sentence, a "Strength" header over an empty-state card, a "Photos every 2 weeks" header over a card with the next date and thumbnails, and (below) coach.

| Element (id) | Decision | Why |
|---|---|---|
| `progress.phase` | **Move to the top under the title:** "Phase 1 · week 1 of 6", with "Week 1 of about 20" quieter beneath it (Advisor) | It is the frame for everything below |
| `progress.weight` | **Becomes the hero number:** "82.7 kg", with "7-day average · −0.7 kg this week" under it | One hero number per screen (`direction.md`) |
| `progress.weightChart` | **Keep**, without its own section header | |
| Strength empty state ("Your lifts appear here…") | **Hide until there is data**; `progress.lift.*` rows then appear | Rule 4 |
| Photos card (`progress.nextPhotos`, thumbnails, `progress.photoSet.*`) | **One disclosure row:** "Photos · next Mon 7 Dec ›". **`progress.photoDay` shows as a card only on photo day** | Shown only when it needs him |
| `progress.coachNote`, `progress.flag.*` | **Keep, only when present** | |
| `progress.askCoach` and `coach.import` | **Keep as two rows at the bottom** | Optional actions, out of the way |
| Section headers "Weight", "Strength", "Photos every 2 weeks" | **Cut**; the content says what it is | Duplicate labels |

**After:** ① phase lines ② hero weight ③ chart ④ lifts (once there are any) ⑤ Photos row.

## 11. Onboarding confirm

**Before:** `onboarding-confirm`. It is one long scroll of 12 rows in 4 sections. The four "Guess" rows are mixed in with eight rows that came from what the owner already said.

| Element (id) | Decision | Why |
|---|---|---|
| `onboarding.title` | **Keep** | |
| The four Guess rows: `onboarding.row.paperStart`, `.sleep`, `.work`, `.longest` | **Keep, at the top, together**, under "Check these 4" | These are the only rows that need a glance |
| The other eight rows (`.you`, `.goal`, `.hurts`, `.office`, `.fixed`, `.kit`, `.cues`, `.checkIn`) | **Move into one disclosure:** "Everything else (8) · from what you told us ›" (new id `onboarding.more`) | They are confirmed already; showing them is admin |
| Section headers (Week, Training, Coach) | **Cut** | Rows read on their own |
| `onboarding.confirm` "Looks right" | **Keep** | |

**After:** ① title ② the 4 Guess rows ③ Everything else ④ Looks right.

## 12. Permissions

**Before:** `onboarding-permissions`. The title says "Two quick yeses", then lists **four** rows, and two of them say "Asked when first needed".

| Element (id) | Decision | Why |
|---|---|---|
| `permissions.title` | **Keep** | |
| Subtitle "So the app can run your day without you checking it." | **Cut** | |
| `permissions.row.health`, `permissions.row.location` | **Cut from this screen**; they are asked in context, as they already say | The title and the list contradicted each other |
| `permissions.row.alarms`, `permissions.row.notifications` | **Keep** | |
| `permissions.continue` | **Keep** | |

**After:** ① title ② two rows ③ Continue.

## 13. Sunday prompt

**Before:** `sunday-prompt`. It is already lean: Cancel, "Week of 23 Nov", the question, five day pills, "Early start or late finish?" and Done. **Keep** it all. One cut: the nav title "Week of 23 Nov" becomes part of the question ("Office days, week of 23 Nov?"). That is one line fewer, and the date stays visible.

## 14. Photo day

**Before:** `photo-day`. **Keep** it all. It is used once a fortnight and already has one primary.

---

## Test impact (for the iOS Interface Engineer and QA)

Every identifier keeps its name. These tests need one extra tap, or a check for absence:

| Test | Change |
|---|---|
| `SundayPromptUITests` (3 taps of `today.planWeekToolbar`) | Tap `today.more` first |
| `AlarmPermissionUITests` and the M0-11b check (`home.spikeTests`) | Tap `today.more` first; the item exists only in spike and debug modes |
| `OnboardingUITests`, rows `you`, `goal`, `hurts`, `office`, `fixed`, `kit`, `cues`, `checkIn` | Tap `onboarding.more` first. `onboarding.row.longest` stays above the fold |
| Any check that `today.alarmBanner` exists after a re-set | Now asserts it **doesn't** appear; the re-set is visible in `debug.launch` (`alarms=`) |
| `ProgressUITests` / `CoachImportUITests` (`progress.weight`) | No change; it is still on Progress, now as the hero |
| `MealsUITests` (`meals.totals`) | No change to the id; the element is now a line, not a card |
| Shots | Re-shoot all of them. Add a **set-screen** shot to the player test |

## Open taste decisions for the CEO (Gate 2 pack, not asked)

1. **Meals totals:** one line with no targets (default), or hidden completely.
2. **Shopping search:** a quiet magnifier per row (default), or a swipe action with no icon.
3. **Today date line:** "Mon 23 Nov · Week 1" (default), or no date line.
4. Still open from `direction.md`: accent colour, always-dark, app icon, rounded numerals.

## Advisor review

Round 1 of 2: pending.
