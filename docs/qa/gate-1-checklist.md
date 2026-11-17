# Gate 1 checklist (internal)

Head of QA · drafted 2026-11-17 · target round ~12 Dec, as soon as M2-05 closes. Signed by the Head of QA and the Advisor (standing order D7: no CEO questions).

**Gate 1 asks:** can the app run the week with no paper? (plan §7: "Owner: stop using paper; the app runs the week"). Judged against the guiding rule: *if it takes thinking or admin time, it has failed.*

**Gate 1 passes when** every line below passes or is on the agreed deferred list, there are no open blockers or majors, and the simulated week (§A) needs only next, done and the Sunday prompt.

Round SHA: `________` (40 chars) · Core tests run: `________` · App build run (dispatched, `screenshots` + `publish_shots`): `________` · Date: `________`

## Round setup

1. HoE freezes merges to blocker and major fixes plus test-only changes (test plan §5).
2. Dispatch **App build** on the round SHA with `publish_shots`. UI-test PNGs land in `qa/gate-0a-shots` `screenshots/ui-tests/`. One run is budgeted at ~21 min (QA-6), with one re-run in reserve.
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
| A12 | Any day · weight | 7-day weight trend and steps from sample data (M2-04) | shot |

**Guiding-rule judgement (QA + Advisor):** count every tap in §A that isn't next, done or the Sunday prompt. Each one is a major unless the Advisor accepts it.

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
- [ ] **M2-05** Sunday prompt under 20 s of taps (UI test) · no notification fires 22:30–06:00 (unit test) · full Today timeline.

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

## E. Hygiene

- [ ] CoachCore is Foundation only (grep).
- [ ] No secrets, health data or photos in the repo.
- [ ] Network calls only to Open-Meteo (grep `URLSession`, `URL(string:`).
- [ ] Screenshots en_GB, 24-hour clock (QA-4).

## Deferred to payment (not Gate 1 lines)

Alarms ringing locked, on Silent and in a Focus · alarms surviving a TestFlight update · lock-screen countdown and voice through headphones while locked, music ducking · real Health scale data · S0 pipeline · notification delivery on a device · the backup Clock alarm for the first week on the app.

## Advisor questions for the co-sign

1. Does the simulated week (§A) match how the CEO's real week 2 should feel, with no paper?
2. Are the E13 outcomes on A8 and A9 right in coaching terms?
3. Any tap in §A beyond next, done and the Sunday prompt that you'd accept?
