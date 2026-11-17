# HealthCoach: CEO review pack (Gate 2)

For review at 20:00 on 18 Nov 2026. Kept by the Head of Engineering (board G2-01).

**Recommendation:** TODO (Head of Engineering, after the QA round). It will be one line: accept the build as ready for the phone, or say what is left first.

**Build reviewed:** TODO (the QA round's commit on `main`, run in the iOS 26 simulator).

## 1. What the app does today

- **Onboarding in two taps.** Everything is pre-filled from your requirements: height, weight, equipment, paper start date (16 Nov) and office pattern. You confirm it once.
- **Today screen.** It shows the day's session, the wake time and the timeline, and warns you if no alarms are set. It knows which week you are in from your paper start.
- **The Sunday prompt.** Office days and early or late starts for the week take under 20 seconds. The planner then places Upper A, run-walk, full body and Upper B around basketball and the office, never on a Wednesday, and protects 7.5 hours of sleep.
- **Wake alarms.** These are set 14 days ahead and re-checked each time the app opens. They only go off on days with a fixed start.
- **Workout player.** It shows an exercise GIF and three coaching cues, then runs the rest timer on the lock screen and in the Dynamic Island, with a voice heads-up naming the next exercise and weight. A whole session needs only "next" and "done". Loads progress on their own, up to the 24 kg dumbbell limit.
- **Run-walk player.** Guided intervals with voice cues, building over Phase 1. In rain, it swaps to an indoor session of the same length ("I'll run anyway" undoes it).
- **Meals with no logging.** Each week plans box nights Mon–Thu, home dinners Fri and Sat, and the Sunday cook, plus breakfasts, office or home lunches and a snack. Every day is pre-ticked and counts as eaten unless you change it. There is one merged top-up list in aisle order with Waitrose search links, and an office lunch list near St James's Market. Creatine and vitamin D are one pre-ticked line.
- **Coach and Progress.** The Progress screen shows the weight trend, sessions done, loads and photo day. The rules engine adjusts calories from the 2-week weight trend within the Advisor's limits and raises a stall flag. "Ask the coach now" builds a summary for Claude, and "Import Claude's reply" applies the reply or rejects it in full.

Meals, top-up and lunch screens: TODO (QA), confirm they are in the round build (board M3-04).

## 2. How to look at it

These are simulator screenshots from the UI tests, one per screen. They are on the review branch `qa/gate-0a-shots`, which never merges.

TODO (QA): re-publish the shots from the round build and refresh these links. The current set is from `f1e5e89`, taken before the meals screens.

| Screen | Screenshot |
|---|---|
| Onboarding: confirm | [onboarding-confirm](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testDefaultsArePreFilledAndTwoTapsConfirm-onboarding-confirm_0_53CB95F4-D71D-4977-99DF-5E4777C79F3E.png) |
| Onboarding: permissions | [onboarding-permissions](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testDefaultsArePreFilledAndTwoTapsConfirm-onboarding-permissions_0_51CD7700-5132-46E5-A5FD-CF190741F5FB.png) |
| Today (Monday, week 1) | [today-2026-11-23](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testEachDayOfWeekOneShowsItsSession-today-2026-11-23_0_B552DB09-6410-4F90-8020-78D11BB34D68.png) |
| Today: alarms off warning | [today-no-alarms-warning](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testDeniedAlarmsShowAWarningNeverAllSet-today-no-alarms-warning_0_67132A59-DA05-41D5-87CE-32F2A519E35C.png) |
| Today: rain swap | [today-weather-swap](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testRainShowsTheIndoorSessionAndRunAnywayPutsTheRunBack-today-weather-swap_0_EB939728-377E-4ABD-99C0-41C5B902A3B0.png) |
| Sunday prompt | [sunday-prompt](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testSundayPromptTakesUnderTwentySeconds-sunday-prompt_0_5FCA7674-34EA-44A3-8DDA-CAD33518692F.png) |
| Alarms set after relaunch | [alarms-after-relaunch](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testAllowingAlarmsSetsFourteenThatSurviveARelaunch-alarms-after-relaunch_0_7D1D4FA7-6C39-465B-A4F1-623ED405EE06.png) |
| Workout player: rest | [player-rest](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testUpperACompletesWithOnlyNextAndDone-player-rest_0_83514994-7E4F-4ED7-A04A-0AAD7657EE26.png) |
| Rest timer on the lock screen | [player-rest-live-activity](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testUpperACompletesWithOnlyNextAndDone-player-rest-live-activity_0_3962DA7B-7E9F-4BC3-9D1A-E8631EE82580.png) |
| Workout done | [player-done](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testUpperACompletesWithOnlyNextAndDone-player-done_0_C68C8FAB-DCB0-4E42-8B0C-3E1D0E9D1366.png) |
| Run-walk player | [run-walk-week1](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testWeekOneRunWalkPlays-run-walk-week1_0_B7456D29-472E-4CF2-8E53-604871C90DEF.png) |
| Photo day | [photo-day](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testPhotoDaySavesBothPosesAndIsThenDone-photo-day_0_B2FD591E-F9FD-4165-ADB4-552A62BC0947.png) |
| Progress | [progress-after-photos](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testPhotoDaySavesBothPosesAndIsThenDone-progress-after-photos_0_5716DFD6-8869-4759-9E6E-531F2899CAC7.png) |
| Ask the coach now | [ask-the-coach-share](https://github.com/aoventuresdomain-cloud/HealthCoach/blob/qa/gate-0a-shots/screenshots/ui-tests/testAskTheCoachOpensTheShareSheet-ask-the-coach-share_0_6A0677DE-E74E-4869-A6F4-4A79C98279AC.png) |
| Meals | TODO (QA): shot from the round build |
| Top-up list | TODO (QA): shot from the round build |
| Office lunch list | TODO (QA): shot from the round build |
| Import Claude's reply | TODO (QA): shot from the round build |

The demo walkthrough of a typical week is the QA round's §A shots (`docs/qa/gate-1-2-checklist.md`). TODO (QA): link it.

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

TODO (QA): fill in after the round. List each open item with its severity, its owner and whether it blocks the phone install.

## 6. Decisions for you

1. **When to pay for the Apple Developer account (about £79 a year) and install on your phone.** This is the one that unlocks everything in the deferred list. Recommendation: TODO (Head of Engineering, after the QA round). Once you say go, the Setup Desk sends one checklist (about 45 minutes), and the team runs the on-phone tests.
2. **Which cut features to bring back, if any.** Covers the evening meal check, the social-meal counter, the photo ghost outline and the mood check. Default: leave them out until you have used the app for a week.
3. **Open taste decisions** from the design pass (`docs/design/ui-pass-1.md`): TODO (Head of Engineering), list them or remove this line.
