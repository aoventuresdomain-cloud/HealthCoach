# M1 screen walk · 2026-11-17

Head of QA. 15 UI-test screenshots on `qa/gate-0a-shots` (`screenshots/ui-tests/`, commit `c14903b`, built from `b6ce204`, run 43982765042), walked against the M1-03 mock-ups (`docs/design/m1/png/`) and the guiding rule. Follows the sanity check in `2026-11-16-m1-sanity.md`.

**Verdict: the core flow works and reads well.** Today names the right session on all 7 days. The player is one-handed, with a big timer, a "Dial to" weight and a big Next. The run-walk screen is clear. QA-2 is proven: "All alarms set (14)" after relaunch.

**Four majors must be fixed or decided before Gate 1: QA-10, QA-11, QA-14 and QA-5b.** None is a blocker.

## Walk

| Screen | Shot(s) | Result |
|---|---|---|
| Onboarding confirm | onboarding-confirm | Pre-filled with GUESS tags and a big "Looks right"; **"You" row is empty (QA-10)** |
| Permissions | onboarding-permissions | Clear, one Continue. Title says "Two quick yeses" over four rows; two say "asked when first needed" (QA-13) |
| Today, Mon–Sun week 1 | today-2026-11-23 … 29 | Right session every day (Upper A, Run-walk, Basketball, Full body light legs, Rest, Upper B, Walk). Big Start at the bottom. **A 05:45 wake on every day, including rest, basketball and Sunday (QA-11)** |
| Today after onboarding (Mon 16 Nov, 09:00) | today-after-onboarding | **Week 1 starts the same day, with Upper A "at 06:00" already 3 hours past (QA-14)** |
| Player, rest | player-rest | 1:14 of 1:15 (75 s from the data), "Dial to 10 kg", +30 s, Next. Matches the mock-up. The top bar (progress, close) is hidden by a test-alarm banner (QA-12). No exercise thumbnail in the Next card (QA-13) |
| Player, done | player-done | Summary of what was logged, Done is big. Shows "1 MINUTES" (QA-13). **No "Next time" loads**, which the mock-up shows (QA-13) |
| Run-walk | run-walk-week1 | Warm-up walk 4:55, "Then jog 1:00", segment bar, Pause. Clear at a glance |
| Today (fixture check) | week1-monday | As Monday above |
| Spike tests after relaunch | alarms-after-relaunch | "All alarms set (14)". **QA-2 closed.** Still reachable from the wrench on Today (hide before Gate 1, already assigned) |
| Live Activity during a rest | — | **Not there yet (QA-5b, open)** |

## Findings

| ID | Severity | Item | Finding | Ask | Before Gate 1? |
|---|---|---|---|---|---|
| QA-10 | Major | M1-04 | The "You" row reads "Add height and weight". Requirements §12 sets the defaults (male, 30, 178 cm, 82 kg) and the mock-up shows them filled in. M1-04 says every default is pre-filled. The UI test checks 6 rows and skips this one | Pre-fill from §12 (as a GUESS if unsure) and add the row to `OnboardingUITests` | Yes |
| QA-11 | Major | M1-05 / M2-01 / M2-02 | Today's timeline (M1 `DayPlan`) shows a 05:45 wake alarm on every day: Friday's rest day, Wednesday's basketball day, and Sunday, where the only thing planned is an **optional** walk "at 06:00". M2-01's `WeekPlanner` already returns no alarm on a day off. If M2-02 schedules alarms from what Today shows, the CEO gets a 05:45 alarm 7 days a week, including Sunday for an optional walk | Drive Today and the alarm schedule from `WeekPlanner`. An optional session never sets or moves an alarm. Add a CoachCore test: no alarm on rest days, and Sunday's optional walk sets none | Yes |
| QA-14 | Major (decision) | M1-04 / M1-05 | Confirming on Monday 16 Nov at 09:00 starts week 1 that day, showing "Upper A at 06:00" three hours late. Also, the CEO has been training from paper Week 1 since about 16 Nov, so the app's week 1 may repeat or misalign with where they really are | Advisor to decide the coaching rule (my suggestion: the app starts at the week the CEO is actually in, worked out from the paper start date and shown pre-filled on onboarding; if confirmed after today's slot, today's session moves to the next free slot or shows as "Do it later today"). Then engineering builds it | Yes |
| QA-5b | Major (open) | M1-06 | No screenshot of the Live Activity during a rest yet | iOS engineer adding it | Yes |
| QA-12 | Minor | tests | The real test alarm set by `AlarmPermissionUITests` fires during later UI tests. A "HealthCoach test alarm" banner covers the top of 9 of the 15 shots, including the player's progress bar and close button. It could also make tests flaky | Cancel the test alarms in that test's tearDown, or run it last on its own simulator | Yes (evidence) |
| QA-13 | Minor (design batch) | M1-06, M1-04 | Against the mock-ups: the done screen has no "Next time" loads (the visible proof that progression is automatic) and says "1 MINUTES". The rest card has no exercise thumbnail and reads "1 set × 8" where the mock-up says "2 sets × 10 each arm". The permissions title says two over four rows. "Still sore from last time?" shows before the first session ever. Today is light while the mock-ups are dark (a taste decision, held for Gate 2 under E8) | Designer and iOS, one batch | "Next time" yes; the rest when convenient |

## Still open from the sanity check

QA-6 (minutes), QA-8 (heads-up test), QA-9 (weeks 2–6 sweep). QA-7 is on the deferred-to-payment list.
