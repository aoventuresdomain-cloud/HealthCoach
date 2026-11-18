# HealthCoach: CEO review pack (Gate 2)

For review at 20:00 on 18 Nov 2026. Kept by the Head of Engineering (board G2-01).

**Recommendation:** accept this build as ready for your phone. Every feature is in, and the internal QA round passed with no blockers or majors. The Advisor co-signed the safety limits. What's left can only be proven on a real phone, so the next step is your go-ahead on the Apple account (§6.1).

**Build reviewed:** `6332a80` on `main`, run in the iOS 26 simulator (CI run 44214998274, all unit and UI tests green).

## 1. What the app does today

- **Onboarding in two taps.** Everything is pre-filled from your requirements: height, weight, equipment and paper start date (16 Nov). You confirm it once.
- **Today screen.** It shows the day's session, the wake time and the timeline, and warns you if no alarms are set. It knows which week you are in from your paper start.
- **The Sunday prompt.** Office days and early or late starts for the week take under 20 seconds. The planner then places Upper A, run-walk, full body and Upper B around basketball and the office, never on a Wednesday, and protects 7.5 hours of sleep.
- **Wake alarms.** These are set 14 days ahead and re-checked each time the app opens. They only go off on days with a fixed start.
- **Workout player.** It shows an exercise GIF and three coaching cues, then runs the rest timer on the lock screen and in the Dynamic Island, with a voice heads-up naming the next exercise and weight. A whole session needs only "next" and "done". Loads progress on their own, up to the 24 kg dumbbell limit.
- **Run-walk player.** Guided intervals with voice cues, building over Phase 1. In rain, it swaps to an indoor session of the same length ("I'll run anyway" undoes it).
- **Meals with no logging.** Each week plans box nights Mon–Thu, home dinners Fri and Sat, and the Sunday cook, plus breakfasts, office or home lunches and a snack. Every day is pre-ticked and counts as eaten unless you change it. There is one merged top-up list in aisle order with Waitrose search links, and an office lunch list near St James's Market. Creatine and vitamin D are one pre-ticked line.
- **Coach and Progress.** The Progress screen shows the weight trend, sessions done, loads and photo day. The rules engine adjusts calories from the 2-week weight trend within the Advisor's limits and raises a stall flag. "Ask the coach now" builds a summary for Claude, and "Import Claude's reply" applies the reply or rejects it in full.

## 2. How to look at it

These are simulator screenshots from the UI tests, one per screen. They come from the review branch `qa/gate-0a-shots`, which never merges.

This set is from the review build `6332a80` (run 44214998274). The links are pinned to that shot commit (`b7911df`), so later runs on the branch can't change what you see.

| Screen | Screenshot |
|---|---|
| Onboarding: confirm | [onboarding-confirm](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testDefaultsArePreFilledAndTwoTapsConfirm-onboarding-confirm_0_8A78D7A5-2E7D-4065-BC81-D8E2DBC9B087.png) |
| Onboarding: permissions | [onboarding-permissions](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testDefaultsArePreFilledAndTwoTapsConfirm-onboarding-permissions_0_43DC3610-3030-44A4-BA7B-E8904284F613.png) |
| Today (Monday, week 1) | [today-2026-11-23](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testEachDayOfWeekOneShowsItsSession-today-2026-11-23_0_5F5352E6-83F4-43ED-AA56-AF59C700F072.png) |
| Today: alarms off warning | [today-no-alarms-warning](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testDeniedAlarmsShowAWarningNeverAllSet-today-no-alarms-warning_0_44C1BF82-9D10-4875-8FD0-45B58D5CA224.png) |
| Today: rain swap | [today-weather-swap](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testRainShowsTheIndoorSessionAndRunAnywayPutsTheRunBack-today-weather-swap_0_249CE80A-1D53-4BB7-A18F-3A6C48C8F9FC.png) |
| Tomorrow changed | [tomorrow-changed](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testTomorrowChangedUpdatesTomorrowAndLeavesTodayAlone-tomorrow-changed_0_B8731063-4397-4EB6-8B9F-55F2B4495E58.png) |
| Tomorrow re-planned | [tomorrow-replanned](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testTomorrowChangedUpdatesTomorrowAndLeavesTodayAlone-tomorrow-replanned_0_2D049551-E736-4085-86A7-AAFB37D357C5.png) |
| Sunday prompt | [sunday-prompt](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testSundayPromptTakesUnderTwentySeconds-sunday-prompt_0_8F4DA989-4678-475C-B784-20B9B5D43DC0.png) |
| The week planned | [a1-week-planned](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testA1SundayPromptThenTheWeeksPlan-a1-week-planned_0_78FA79D4-8358-497E-A1DD-6432C24899EB.png) |
| Alarms set after relaunch | [alarms-after-relaunch](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testAllowingAlarmsSetsFourteenThatSurviveARelaunch-alarms-after-relaunch_0_D765686E-D6DE-4715-AA3C-0DAEF17FA8E2.png) |
| Workout player: set | [player-set](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testUpperACompletesWithOnlyNextAndDone-player-set_0_33FAD5E2-0038-4EA7-8F58-5AD6FCB31D79.png) |
| Workout player: rest | [player-rest](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testUpperACompletesWithOnlyNextAndDone-player-rest_0_E61F1608-50EC-4366-9B1B-3F7750904BD3.png) |
| Rest timer on the lock screen | [player-rest-live-activity](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testUpperACompletesWithOnlyNextAndDone-player-rest-live-activity_0_7629C62E-8963-44DB-BC75-C649BA106C9A.png) |
| Workout done | [player-done](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testUpperACompletesWithOnlyNextAndDone-player-done_0_37AD15F4-9432-43AF-9591-83496C6FD133.png) |
| Run-walk player | [run-walk-week1](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testWeekOneRunWalkPlays-run-walk-week1_0_8A7896C9-0935-45D2-A424-AF90C4B33D61.png) |
| Meals | [meals-today](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testMealsArePreTickedAndUntickingChangesTheTotal-meals-today_0_561204FE-D6BA-47FC-9B2E-6AD8BEBB4E7B.png) |
| Recipe | [recipe](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testMealsArePreTickedAndUntickingChangesTheTotal-recipe_0_C3C15F84-F729-496C-BDA9-150D91BAC7F9.png) |
| Top-up list | [shopping](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testShoppingTicksAndLunchList-shopping_0_64CF52D4-4CCC-491B-9584-DBDACF8E3F41.png) |
| Office lunch list | [lunch](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testShoppingTicksAndLunchList-lunch_0_5B170239-C64F-4EE5-8BA7-ADD2731E3E2F.png) |
| Photo day | [photo-day](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testPhotoDaySavesBothPosesAndIsThenDone-photo-day_0_8CBAB69D-3AC8-410D-996F-741F30F937CF.png) |
| Progress | [progress-after-photos](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testPhotoDaySavesBothPosesAndIsThenDone-progress-after-photos_0_562F2492-A99D-46DD-87A8-0590A3794033.png) |
| Ask the coach now | [ask-the-coach-share](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testAskTheCoachOpensTheShareSheet-ask-the-coach-share_0_56605360-C460-4A7C-A0B0-62279A919D8A.png) |
| Import Claude's reply | [a17-imported](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testA17ValidReplyImportsAndShowsTheNextDay-a17-imported_0_8575C6E5-2ACF-461B-A664-8174016BE693.png) |
| A bad reply refused in full | [a17-refused](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testA17BadReplyIsRefusedAndNothingChanges-a17-refused_0_6C14506E-63C1-423C-BE58-D3E30F8D9A66.png) |

A typical week, day by day: [a5-tuesday-run](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testA5TuesdayRunBeforeTheEarlyStart-a5-tuesday-run_0_D611ED3C-A332-4DB2-882C-A14F217BE52C.png), [a7-wednesday-rest](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testA7WednesdayRestNoAlarm-a7-wednesday-rest_0_1EDCA381-7E33-4A92-AE2F-7AA2D7119634.png), [a8-moved-to-friday](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testA8A9MissedFullBodyMovesToFridayAndHolds-a8-moved-to-friday_0_B63696DB-9C54-4B59-A022-64DE27162C3B.png), [a9-friday-holds](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testA8A9MissedFullBodyMovesToFridayAndHolds-a9-friday-holds_0_FF21C8EE-8FB5-487A-AAB2-FE12A196AEE3.png), [a10-saturday-upper-b](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testA10A11TheWeekend-a10-saturday-upper-b_0_227DA317-D48F-4675-8E4B-EE7D58CC766D.png), [a11-sunday-walk](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/b7911dfd9104dbabcd847180a0f201785de8c68f/screenshots/ui-tests/testA10A11TheWeekend-a11-sunday-walk_0_5B482EE7-5637-4865-A297-777F1A88337D.png). The full walk-through and verdicts are in the [QA round report](../qa/rounds/2026-11-18-gate-1-2.md).

## 3. What was cut or deferred, and why

**Cut to have the whole app ready in 1–2 days (your re-plan, 17 Nov).** Each can come back later. None leaves a dead button or a screen that promises it.

- **Evening meal check ("anything different?").** Meals now count as planned unless you change them. The Advisor accepts this as the logging model, because the coach steers by the scale, not by meal logs.
- **Social-meal counter** (2 untracked meals a week).
- **Photo ghost outline.** Photo day still saves both poses every 2 weeks, without the outline to line up against.
- **Mood check.**

**Built but not provable without the paid Apple account and your phone.** About 45 minutes of setup and 15 minutes of on-phone tests once you pay (board, "Deferred to payment"):

- Alarms ringing with the phone locked, on Silent and in a Focus mode.
- Alarms surviving an app update.
- The lock-screen timer and voice cues through headphones while locked, with music ducking.
- Real data from your Health scale (the simulator uses sample data).
- Notifications delivered on a real device.
- The pipeline that installs every change on your phone (Xcode Cloud and TestFlight).
- A backup Clock alarm for your first week on the app.

**Risk:** the alarm and timer code ship unproven on a device. If a device test fails, only that phone layer is reworked. The coaching logic is device-independent and fully tested.

## 4. Safety limits in force (Advisor)

- **Calories:** 2,000 a day to start, with 160 g protein. The target only changes on the 2-week weight trend, by at most 100 kcal a week, and not at all in weeks 1–2.
- **Floors:** never below 1,850 kcal as the weekly target, and no single day below 1,700. Each day is planned within ±150 kcal of the week's target, with at least 150 g protein.
- **Cut ceiling and maintenance:** at most 2,200 while cutting. Weeks 13–14 are maintenance at 2,450.
- **Stall flags:** weight flat for two checks, a wanted step below the floor, or losing over 1.2 kg a week (1.0 in Phase 3) at the ceiling. A flag shows one line on Today and never changes the plan by itself.
- **Claude's replies are checked before they apply.** A reply is rejected in full, with your plan left unchanged, if it sets calories outside 1,850–2,200 (2,300–2,600 in maintenance) or protein outside 140–180 g. It is also rejected if it sets a dumbbell load over 24 kg, drops below 2 strength sessions, or tries to add or move a session.
- **Training:** never a session on Wednesday (basketball), never two sessions in a day. A missed session moves once, or is dropped quietly, with no guilt copy.
- **Supplements:** creatine 5 g daily and vitamin D 10 µg (October to March), pre-ticked with breakfast.
- **Privacy:** health data and photos stay on the phone and your own iCloud backup. The only thing that leaves is the Claude summary you choose to share, which holds averages only, with no name, photos or raw Health samples. The only network call is the weather (Open-Meteo, no key).

## 5. Known issues

The internal round passed on the review build (`6332a80`), with no blockers and no majors open. Full record: [`docs/qa/rounds/2026-11-18-gate-1-2.md`](../qa/rounds/2026-11-18-gate-1-2.md).

| Issue | Severity | Owner | Blocks the phone install? |
|---|---|---|---|
| "Tomorrow changed" can't skip basketball yet, because that needs a new planner field (M2-06 follow-up) | minor | Planner Engineer | No |
| One automated test (alarm permission) passes by retrying instead of waiting properly for the app to settle (QA-38) | minor | iOS Interface Engineer | No |
| If you open the ⋯ menu in the first second after launch, it can close by itself; tap it again (QA-39) | trivial | iOS Interface Engineer | No |
| GitHub's Mac build machines were short on 17 Nov, and one build needed three attempts. That's GitHub capacity, not our budget. | trivial | Head of Engineering | No |

**Tested only in the simulator until the phone install** (needs the paid Apple account, your call in §6):
- alarms firing for real on a locked phone, on Silent and in a Focus
- the rest timer on the real lock screen and Dynamic Island
- real weight and steps from your scale and Apple Health (the simulator uses sample data)

## 6. Decisions for you

1. **When to pay for the Apple Developer account (about £79 a year) and install on your phone.** This is the one that unlocks everything in the deferred list. Recommendation: pay now. The simulator has taken this as far as it can, and the alarms are the part most likely to need rework on a real phone. Finding that in week 1 is far cheaper than in week 6. Nothing else in the plan needs a paid service. Once you say go, the Setup Desk sends one checklist (about 45 minutes), and the team runs the on-phone tests.
2. **Which cut features to bring back, if any.** Covers the evening meal check, the social-meal counter, the photo ghost outline and the mood check. Default: leave them out until you have used the app for a week.
3. **Small taste calls from the declutter pass** (`docs/design/ui-12-declutter.md`). Each is built with the default. Tell us only if you want the other one.
   - Meals totals: one line with no targets (default), or hidden.
   - Shopping search: a quiet magnifier on each row (default), or a swipe.
   - Today's date line: "Mon 23 Nov · Week 1" (default), or none.
   - Accent colour, always-dark look, app icon and rounded numbers: current choices stay unless you'd like a change.
