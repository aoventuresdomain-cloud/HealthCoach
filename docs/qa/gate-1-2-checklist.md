# Combined Gate 1 + Gate 2 checklist (internal)

Head of QA · drafted 2026-11-17, extended the same day for the CEO's re-plan: the whole app is ready for review in 1–2 days, so Gate 1 and Gate 2 are one internal QA round. Signed by the Head of QA and the Advisor (standing order D7: no CEO questions).

**Timetable (London):** PRs re-checked as they land on 17 Nov · Designer's change list 16:00 · full UI dry run once M3-04 lands · iOS polish PR by 06:00 on 18 Nov · **round on one frozen SHA, morning of 18 Nov** · fix and retest 18 Nov 12:00–18:00 · round closed and report merged by 18:00.

**The round asks:** can the app run the week, training and eating, with no paper? (plan §7, Gates 1 and 2). Judged against the guiding rule: *if it takes thinking or admin time, it has failed.*

**The round passes when** every line below passes or is on the agreed cut or deferred list, there are no open blockers or majors, and the simulated week (§A) needs only next, done and the Sunday prompt.

Round SHA: `________` (40 chars) · Core tests run: `________` · App build run (dispatched, `screenshots` + `publish_shots`): `________` · Date: `________`

## Round setup

1. HoE freezes merges to blocker and major fixes plus test-only changes (test plan §5).
2. Dispatch **App build** on the round SHA with `publish_shots`. UI-test PNGs land in `qa/gate-0a-shots` `screenshots/ui-tests/`. CI minutes are no longer a constraint (CEO, 17 Nov), so the full UI suite runs on every fix in the 12:00–18:00 window, and a dry run happens on 17 Nov evening once M3-04 lands.
3. Core tests run green on the same SHA (Linux).

## A. The simulated week (the gate itself)

One scripted week on the injected clock: a hybrid week 2 (office Mon, Tue, Thu; early Tue 08:00; late Thu 19:00), plus a missed-session day. It runs as one UI test, or a chain of them, with `-now` steps and the `week2-hybrid` fixture (new; the Planner adds it). A CoachCore twin runs the same week to check the numbers.

| # | Step (`-now`, London time) | Expected | Evidence |
|---|---|---|---|
| A1 | Sun 22 Nov 18:00 · Sunday prompt | Answered in under 20 s of taps (M2-05). The week's plan shows straight after | UI test timing + shot |
| A2 | Sun 22 Nov 18:01 · alarms | 7–14 days registered, the alarm days exactly as E14 (session or office days only; no Wednesday or Sunday walk alarm) | debug line + CoachCore twin |
| A3 | Mon 06:30 · Today | Upper A this morning; the time matches the alarm; leave time for the office | shot |
| A4 | Mon · workout | Full Upper A touching only next and done; rest from `phase-1.json` per block; 10 s heads-up text; done as prescribed logs it | UI test (M1-06) |
| A5 | Tue 07:00 · Today | Run 1 with run-walk; next session's loads changed after Monday's log (M1-08) | shot + CoachCore |
| A6 | Tue · rain fixture (`-weather rain`) | Run swapped indoors, same length, wake time unchanged (M2-03) | shot |
| A7 | Wed · Today | Rest, no alarm, no session; wind-down tonight from tomorrow's alarm | shot |
| A8 | Thu 21:00 · full body not logged | Passed session moves per E13 (evening if ≥ 2 h before wind-down, else next free legal day this week, else dropped quietly, with no guilt copy) | shot + CoachCore |
| A9 | Fri 07:00 · Today | **The moved session is still there, with its alarm (QA-15)** | shot + debug line |
| A10 | Sat · Today | Upper B at the day-off time; Saturday's wind-down matches the weekday median (E14) | shot |
| A11 | Sun · Today | Optional walk shown, no alarm; Sunday prompt notification due at its time, not in quiet hours | shot + unit test |
| A12 | Any day · weight | 7-day weight trend and steps from sample data (M2-04) | shot (`week2-hybrid` fixture Health data: 81.7 kg on Mon 23 Nov, down 0.5 kg; steps must be visible somewhere, QA-30) |
| A13 | Mon–Sun · Today's daily band | Meals for the day shown in the band, pre-ticked, protein about 160 g and calories at the phase target; nothing to tap if eaten as planned (M3-02) | shot + CoachCore |
| A14 | Sun 18:05 · top-up list | One merged list for the week, sorted by aisle, staples once, a search link per item (M3-03) | shot |
| A15 | Mon, Tue, Thu · office lunch | The lunch card suggests one order on office days only (M3-04) | shot |
| A16 | Sun · Progress | Weight trend, sessions done, loads; "Ask the coach now" builds a summary and opens the share sheet (M4-03, M4-02) | shot |
| A17 | Sun · import | A valid Claude block pasted changes next week's plan; a bad one is rejected plainly and the plan stays (M4-02) | UI test + CoachCore |
| A18 | Mon 07:00 · Today | "Tomorrow changed" opens tomorrow's answers only; saving re-plans that one day (alarm, timeline, notifications) and leaves today and every other day as they were; ignoring the button changes nothing (M2-06) | UI test + shot + debug line (`alarms=` and `next=`) |
| A19 | Every Today and Onboarding shot | No wrench (Spike tests) on Today or Onboarding in any normal or review shot; Spike tests still reachable with `-spikeAlarms` (M0-11b) | all shots + `AlarmPermissionUITests` green |

**Guiding-rule judgement (QA + Advisor):** count every tap in §A that isn't next, done or the Sunday prompt. Each one is a major unless the Advisor accepts it.

**Advisor's provisional rulings (17 Nov 12:10 UTC; confirmed in the fix window):**
- **Taps accepted** (optional, and ignoring them gives the right result): the Fine/Sore row (pre-set to Fine), "I'll run anyway", "Something was different", "Tomorrow changed", the tap counter, "+30 s", and A16–A17 (started by the CEO). **Majors:** any required tap, a confirmation dialog, a permission re-prompt after onboarding, or a meal that must be ticked to count.
- **A8:** Thursday full body moving to Friday, the day before Saturday's Upper B, is a legal outcome at week-2 effort, not a defect. QA-15 stays a blocker.
- **Pre-ticked meals** are accepted as the logging model, not a stopgap. The engine steers by the scale.
- **Values to test against** (the code may lag): protein 160 g · Phase 1 target 2,000 kcal · each day within the weekly target ±150 kcal, never under 1,700 (A13 tests this relative to the target, replacing the fixed 1,850–2,150 band) · engine floor 1,850, cut ceiling 2,200, maintenance 2,450 · steps of at most 100 kcal a week on a 2-week trend, none in weeks 1–2 · import bands: calories 1,850–2,200 (2,300–2,600 in maintenance), protein 140–180 g, loads up to 24 kg.

## B. M1 · Workout (Done when lines)

- [ ] **M1-01** Store won't open → recovers with a one-line notice, no crash · newer or broken file rejected with a plain message · every `Content/` file validated by a CoachCore test · `exercises.json` at schemaVersion 1.
- [ ] **M1-02** Weeks 1–6 match plan §2 (3 strength + run-walk + basketball; second run from week 4; light legs to week 4; nothing on Wednesday) · three callouts per exercise.
- [ ] **M1-04** Onboarding UI test confirms in under 5 min of taps, every default pre-filled (E6, E12; QA-10 "You" row) · start week pre-filled from the paper start and marked as a guess (E13) · stored in the profile.
- [ ] **M1-05** Today right for any date in weeks 1–6 (UI test across 7 days; PlanSweepTests across 42 days, QA-9).
- [ ] **M1-06** Rest per block, 90 s only as fallback (CoachCore test) · 10 s heads-up names the next exercise and weight (unit test, QA-8) · full session with only next and done (UI test) · GIFs bundled, no network · Live Activity starts and ends with each rest (QA-5b shot mid-rest).
- [ ] **M1-07** Week 1 run-walk (1:1 × 10) plays with voice cues on the injected clock; later weeks build to 5 km.
- [ ] **M1-08** Loads change correctly after logging · 24 kg flag · drop to 2 sessions.

## C. M2 · Planner (Done when lines)

- [ ] **M2-01** At least 6 office-day patterns placed correctly, never Wednesday · wake = first commitment − commute − shower − session − buffer, protecting 7.5 h sleep · E13 passed sessions, including **the move surviving the next day (QA-15)**.
- [ ] **M2-02** 7–14 days of alarms kept across simulated opens with no owner action · "tomorrow changed" re-plans one day only · empty-plan guard · zero alarms always warns on Today (QA-1) · XCUITest: Allow → 14 set → relaunch → "All alarms set (14)" (QA-2 re-verify) · alarm days per E14 (QA-11).
- [ ] **M2-03** Bad forecast swaps the run indoors, same length, same wake · offline means no swap, no error.
- [ ] **M2-04** 7-day weight average from sample Health data · no health data leaves the phone (diff: only Open-Meteo calls).
- [ ] **M2-06** "Tomorrow changed" button on Today re-plans one day only through `AlarmSchedule.replacingDay`; every other day's alarm untouched (A18) · optional tap, so it is not a required tap.
- [ ] **M2-05** Sunday prompt under 20 s of taps (UI test) · no notification fires 22:30–06:00 (unit test) · full Today timeline.

## C2. M3 · Meals (Done when lines, as re-planned)

- [ ] **M3-01** Box-night calories and protein entered · 3–4 breakfasts, home lunches and 1 Sunday cook, all 2 portions, with calories and protein · 5–6 lunch orders within 8 minutes' walk of St James's Market · every recipe validated by a content test (L2).
- [ ] **M3-02** Meal plan in Today's daily band, pre-ticked · daily protein planned at about 160 g, calories match the phase target (CoachCore test, Advisor-reviewed) · a simulated week of eating needs no taps when eaten as planned. *(Evening "anything different?" prompt and the social-meal counter: cut, see below.)*
- [ ] **M3-03** One merged weekly list sorted by aisle · staples ticked once · each item has a search link to the default shop (E5) · links are plain search URLs, no API, no account.
- [ ] **M3-04** Meals, top-up and lunch screens walked in the simulator against the guiding rule · the lunch card suggests one order on office days.

## C3. M4 · Coach (Done when lines, as re-planned)

- [ ] **M4-01** A simulated 2-week stall raises a flag · calories adjust from the 7-day trend within safe bounds (Advisor-reviewed values) · load from logs, volume from recovery.
- [ ] **M4-02** The summary holds only what the CEO chooses to share, through the share sheet; nothing is sent automatically, and there is no API call · an imported block changes next week's plan · a malformed or wrong-version block is rejected with a plain message and last week's plan stays (CoachCore tests).
- [ ] **M4-03** Progress view shows the trend, sessions and loads · "Ask the coach now" builds a summary and opens the share sheet. *(Photo ghost outline and mood check: cut, see below.)*
- [ ] **G2-01** Demo walkthrough of a typical week (UI-test shots from §A) · the deferred and cut lists · open taste decisions · one recommendation on payment.

## Cut and deferred by the re-plan (17 Nov, not round lines)

Each is checked only for absence: no dead button, empty screen or copy promising it.

- Evening meal prompt ("anything different?")
- Social-meal counter (2 untracked meals)
- Photo ghost outline
- Mood check

## C4. Look and feel (CEO, 17 Nov: easy to use and cool, to researched best practice)

Judged against `docs/design/ui-pass-1.md` (UI-1 to UI-13, each with Done when lines) and `docs/design/direction.md`, on the round's UI-test shots at the iPhone Pro size, en_GB.

- **P1, UI-1 to UI-6 (must ship):** each Done when line is a round line. A failure is a minor, or a major where it breaks a hard rule.
- **P2, UI-7 to UI-11, and P3, UI-12 and UI-13 (if time allows):** if missing, record "not built", not a fail. If built, check them against their Done when lines.
- **Hard rules (major if broken):** no new required tap · next and done never hidden · every existing accessibility identifier unchanged.
- **Quick visual checks:** every screen dark · green accent, with no system blue except rest and walk · glass only on the close and secondary buttons and the tab bar · the app opens on Today · no tab bar mid-session (player, run-walk, walk) · a tab with no content yet shows its one-line `ContentUnavailableView`, never an empty screen.

General lines:

- [ ] **No new required taps.** The polish adds no step, dialog or control that the §A week needs. Re-count against the Advisor's accepted-tap list.
- [ ] One-handed: next and done stay big, in the lower third and in thumb reach on every workout and run screen.
- [ ] Hierarchy: each screen has one obvious primary action and one main number or time, readable at arm's length.
- [ ] Consistency: one type scale, spacing and corner radius, plus SF Symbols, across Today, player, run-walk, meals, top-up, lunch and Progress.
- [ ] Dynamic Type at the largest standard size: nothing clipped or overlapping (one shot each, of Today and the player).
- [ ] Accessibility: VoiceOver labels on every control, and the accessibilityIdentifiers the UI tests rely on are unchanged.
- [ ] Motion: transitions are short and never delay next or done. Reduce Motion is respected.
- [ ] Copy: plain, British, no guilt copy (E13), and no text promising a cut feature.
- [ ] Live Activity and Dynamic Island match the in-app style.

Any line that fails is a minor, unless it adds a required tap or hides next or done, which is a major.

## D. Carried QA items to close in this round

| ID | Line | Status at drafting |
|---|---|---|
| QA-1, QA-2 | Re-verify on the round SHA | closed 2026-11-17; re-verify |
| QA-5b | Live Activity shot while backgrounded mid-rest | added in #34; not yet viewed |
| QA-6 | macOS minutes per run inside budget | open |
| QA-10, QA-13 | Onboarding "You" row; "Next time" loads on the done screen | in #38 |
| QA-15 | E13 move survives the next day, with its alarm | **blocker, open** |
| QA-16, QA-17 | Evening start stays put; held-at-week-6 flag visible to the team | minor, open |
| M0-11 | Spike tests screen hidden outside test modes | done (#34); re-check on a normal launch shot |
| M0-11b | Wrench hidden on Today and Onboarding (gap found 17 Nov; still visible on b59f62d shots) | fix PR tonight; check as A19 |
| QA-30 | Steps are read from Health (`BodyStats.steps`) but shown nowhere, so A12's "and steps" can't pass | minor, open (dry run b59f62d) |

## E. Hygiene

- [ ] CoachCore is Foundation only (grep).
- [ ] No secrets, health data or photos in the repo.
- [ ] Network calls only to Open-Meteo (grep `URLSession`, `URL(string:`); shop search links open in the browser only when tapped.
- [ ] Health data and photos go nowhere except the CEO's own iCloud backup and the summaries they choose to share.
- [ ] Screenshots en_GB, 24-hour clock (QA-4).

## Deferred to payment (not Gate 1 lines)

Alarms ringing locked, on Silent and in a Focus · alarms surviving a TestFlight update · lock-screen countdown and voice through headphones while locked, music ducking · real Health scale data · S0 pipeline · notification delivery on a device · the backup Clock alarm for the first week on the app.

## Advisor questions for the co-sign

1. Does the simulated week (§A), training and eating, match how the CEO's real week should feel, with no paper?
2. Are the E13 outcomes on A8 and A9 right in coaching terms?
3. Any tap in §A beyond next, done and the Sunday prompt that you'd accept?
4. Are the M3-02 protein and calorie targets and the M4-01 safe bounds the values you signed off?
5. With the evening prompt cut, is "pre-ticked as planned" an acceptable way to log meals until it returns?
