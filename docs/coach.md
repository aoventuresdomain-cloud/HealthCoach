# Coach: rules engine and Claude import (board M4-01, M4-02)

CoachCore only. Numbers are the Advisor's ruling of 17 Nov 2026 (also in `docs/qa/gate-1-2-checklist.md`).

## Rules engine (`CoachReview.make`)

One call gives everything the coach decides for a day: calories, dropped sessions, dumbbell-limit list, flags and the latest imported note. It is stateless: it replays from the programme start using the weigh-ins, the session logs and the accepted Claude blocks. The app stores only the blocks (`CoachBlock.storedData` / `stored(from:)`).

**Calories (`CalorieRules`).** Start 2,000 kcal, protein 160 g. Each Monday from week 3, the 2-week rate is checked: (7-day average ending Sunday − the one 14 days earlier) / 2, with at least 3 weigh-ins in each window.

| Phase | Aim (kg/week) | Step down below | Step up above |
|---|---|---|---|
| 1–2 | 0.4–0.8 | 0.3 (or a gain) | 1.0 |
| 3 | 0.3–0.6 | 0.2 | 0.8 |

- A step is 100 kcal, never more than one a week. Cut band 1,850–2,200; a step near an edge stops at the edge.
- No checks in weeks 1–2, or with too few weigh-ins (target unchanged).
- Weeks 13–14 (overall) are maintenance: fixed 2,450, no steps, no flags. The cut target is carried across the break.
- After a planned change of 200 kcal or more (into or out of maintenance, or an import), the next 2 checks are skipped; after a smaller import, 1.
- `CalorieTarget.dayBand` is the band the meal planner (M3-02) plans each day inside: the weekly target ±150, never under 1,700.

Phase 3's step thresholds (0.2 and 0.8) follow the same offsets from the aim as phases 1–2; the Advisor ruled only the aim, so this is flagged for confirmation.

**Load.** Progression (M1-08) as before. `Programme.prescription(for:week:history:blocks:on:)` adds imported loads: an imported weight holds until the owner next logs that exercise, at the bottom of the range (`step == .coach`); after that the logged weight leads, as usual.

**Volume.** The R2 reduced week (two Sore checks) plus any imported `dropSessions`. Pass `review.droppedSessions` to `WeekPlanner.plan(dropping:)` and `DayPlan.make(dropping:)`.

**Flags** (never change the plan):

- `stall(.weightFlat)`: the 2-week rate under 0.2 kg a week (or a gain) at two consecutive checks.
- `stall(.calorieFloor)`: the last check wanted to go below 1,850.
- `stall(.losingTooFast)`: over 1.2 kg a week at two consecutive checks while at the 2,200 ceiling (muscle-loss risk).
- `checkpoint(n)`: from the Saturday of week 6, 14 or 20 to the end of the following week.

Any flag clears once a block is imported after it was raised. `CoachFlag.line` is the one line for Today.

## Claude summary and import

`CoachSummary.text(reason:programme:profile:history:weights:steps:blocks:now:calendar:) -> String?` builds the text for the share sheet (nil before onboarding). It carries averages only: no name, photos or raw Health samples. It ends with the reply format and its rules, and its example uses today's numbers, so a block copied unedited changes nothing by accident (a test imports the example back).

The reply block:

```
BEGIN HEALTHCOACH BLOCK
{"format": "healthcoach-coach-block", "schemaVersion": 1, "note": "…", "dailyKcal": 1950,
 "proteinG": 160, "dropSessions": ["full-body"], "dropForWeeks": 1,
 "loads": [{"exercise": "dumbbell-bench-press", "kg": 14}]}
END HEALTHCOACH BLOCK
```

`CoachImport.importing(clipboard, into: blocks, …)` returns the list to store and the one line to show. A good block is stamped `effectiveFrom` = tomorrow. Anything wrong rejects the whole block, the list comes back unchanged, and the message ends "Your plan hasn't changed." It is rejected when:

- there is no block, or the clipboard is over 64 KB;
- the JSON is broken, the format is wrong, or the version is newer or older than 1;
- it has an unknown field (so a typo is never silently ignored), or it changes nothing;
- `dailyKcal` is outside 1,850–2,200 (2,300–2,600 when it starts in a maintenance week), or `proteinG` is outside 140–180, or either isn't a whole number;
- `dropSessions` names a fixed event (basketball), an unknown session, or leaves fewer than 2 strength sessions; `dropForWeeks` must be 1–4;
- a load isn't a dumbbell exercise in the programme, is over 24 kg (or the profile's heaviest dumbbell), or isn't a multiple of the 2 kg step;
- the note is over 280 characters.

A block can only drop sessions, never add or move one, so it can't put a session on Wednesday or go past 4 strength sessions (Advisor point 6). `dropForWeeks` counts whole weeks from the first Monday on or after the block applies, so a Saturday import drops the whole of next week.

**Assumption:** overall weeks count from `Profile.programme.startDate` (the paper start, E13) across all phases. If a later phase resets the start date, maintenance and checkpoint weeks need an offset.
