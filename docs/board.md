# Work board

Kept by the Head of Engineering, the only one who merges. One owner per item. Status: `todo` · `in progress` · `in review` · `done` · `blocked`.
QA label: **core** = full end-to-end round (CoachCore, alarm scheduling, Health, data model, Claude import, pipeline); **interface** = sanity plus a walk of changed screens; **docs** = sanity only. Unlabelled means core.

**🙋 CEO hands** marks steps that need the owner's hands. Engineers never ask the CEO; the Setup Desk batches every 🙋 step into one checklist, verifies the result and tells the owner.

## Roadmap to Gate 2 (standing order, 2026-11-16 21:10)

The CEO is training from paper and will not be asked anything until Gate 2. The team decides, records the decision in `docs/decisions.md` and carries on. CEO time is 0 h a week until Gate 2. Work is proven by CI, CoachCore tests, simulator UI tests and screenshots. Anything that needs the paid account or the phone is built, flagged under **Deferred to payment**, and never asked about.

| Step | Purpose | Sign-off | Target |
|---|---|---|---|
| **M0a** | CI compiles everything, spike code checked in the simulator | Head of Engineering | 20 Nov |
| **Gate 0a** (internal) | Simulator proof of spikes; deferred list agreed | Head of QA + Advisor | 21 Nov |
| **M1** · Workout | Phase 1 programme, onboarding confirm, Today, workout player, run-walk, one-tap logging, progression | Head of Engineering | 4 Dec |
| **M2** · Planner | Sunday prompt, placement, wake times, 14-day alarms, weather swap, notifications, Health trend | Head of Engineering | 11 Dec |
| **Gate 1** (internal) | A simulated week runs from the app with no paper, judged against the guiding rule | Head of QA + Advisor | 12 Dec |
| **M3** · Meals | Box nights, breakfasts, Sunday cook, top-up list, office lunch list | Head of Engineering | 18 Dec |
| **M4** · Coach | Rules engine, stall flag, Claude summary and import, progress, photos, Ask the coach now | Head of Engineering | 23 Dec |
| **Gate 2 pack** | Full QA round, a release-ready simulator build, a demo walkthrough, the deferred list, and one recommendation on payment | Head of Engineering | 20:00, 18 Nov (re-plan 17 Nov; was 27 Dec) |
| **Gate 2** | CEO reviews and decides how to move | **CEO** | from 18 Nov |
| Run | Phase 2 and 3 programmes as data | Researcher | before weeks 7 and 15 |

**Cut rule:** if any milestone slips more than a week, cut M3 extras first (in-store mode, delivery reminder, lunch swipe), then M4 photos.

**Deferred to payment (built, not provable until the CEO says when):** S0 pipeline to the phone (M0-03). S1 alarms ringing locked, on Silent and in Focus. S1b alarms surviving an update. S3 lock-screen timer and voice through headphones while locked. Real Health scale data. Backup Clock alarm for the first week on the app. Xcode Cloud GIF fetch in `ci_scripts` (QA-7). Music ducking under voice cues with real music. All need ~45 min of setup and ~15 min of on-phone tests once paid; the Setup Desk checklist already covers them (Parts A–D). **Risk:** alarm and timer code ship unproven on a device; M2's wake alarms depend on it. If the device tests fail later, only the AlarmKit and ActivityKit layer is reworked, because CoachCore is device-independent.

## Next: complete the app (CEO, 18 Nov 07:43)

The CEO will decide when to pay. Everything else gets completed: (1) the coach can adjust the plan end to end, (2) meals are tied to the targets and to training, (3) workouts progress across all three phases. Paid-account items stay built, flagged and deferred. ETA: merged by 17:00 London, a QA round by risk and the Advisor's co-sign by 21:00, pack addendum by 21:30, all on 18 Nov.

| ID | Item | Owner | Areas | Status |
|---|---|---|---|---|
| C1 | Coach loop end to end: one scenario test from weights and logs to calorie change, meal plan, import and loads; summary carries meal adherence, social meals and recovery | Coach Engineer | core | done (#89) |
| C2 | Stall flag, checkpoint-due and dumbbell-limit lines on Today (one line, tap opens Progress) | iOS Interface Engineer | interface | done (#91) |
| C3 | Meals follow the target: training and rest days split around the weekly target, protein floor, maintenance weeks, shopping list re-derives | Planner Engineer | core | done (#88) |
| C4 | Social-meal counter brought back (2 a week): logging one replaces that dinner and the week rebalances inside the floors | Planner Engineer (core), iOS Interface Engineer (one tap on Meals) | core, interface | done (#88 core, #99 UI) |
| C5 | Phase 2 (weeks 7–14) and Phase 3 (weeks 15–20) programmes as data, with callouts | Researcher (Advisor reviews) | docs | done (#86) |
| C6 | Progression across phases, and visible: the player shows "last time → today" on each lift | Planner Engineer (core), iOS Interface Engineer | core, interface | done (#88 core, #91 UI) |
| QA-R3 | QA round by risk on one build: C1 limits first, then C3/C4 floors, then C5/C6 | Head of QA (Advisor co-signs) | docs | done: PASS on `390cf4a`, no blockers or majors, Advisor co-signed (#115); R3-1/R3-2 fixed (#116); R3-3 social-meal header wording in #119 |

**Done when**
**C1** · A CoachCore test runs 4 weeks of fixture weights and logs: the target moves at most 100 kcal a week and never below the floors; next Monday's meal plan uses the new target; an accepted import changes Thursday's load in the workout script; an out-of-limit import leaves calories, meals and loads all unchanged.
**C2** · With a flat-weight fixture, Today shows one stall line; tapping it opens Progress with "Ask the coach now"; no line when nothing is flagged; ordinary shots unchanged.
**C3** · Tests at 1,850, 2,000, 2,200 and 2,450 kcal: every planned day within ±150 of target, none below 1,700, protein at least 150 g each day, weekly average within 50 kcal; training days carry more than rest days; box nights Mon–Thu kept; the top-up list changes when the target does.
**C4** · Logging a social meal on Friday removes Friday's planned dinner, the remaining days stay inside the floors, the counter shows "1 of 2", a third is allowed but flagged in the summary; a UI test covers the tap.
**C5** · Content validation passes for both files; every exercise has three callouts and a GIF; equipment stays within the 24 kg dumbbells, bench and pull-up bar; never Wednesday; the Advisor signs off.
**C6** · Fixture histories show loads carried from week 6 into week 7 and week 14 into week 15; a UI test sees the second Upper A open at a higher load after an all-done first, with "last time" shown.

### Wave 2: close the gap list (CEO, 18 Nov 07:45)

The CEO said the app isn't close to the brief. Advisor questions A1–A4 are answered (#92), so nothing is gated on the Advisor. Wave 2 comes from [`docs/review/gap-analysis-and-build-plan.md`](review/gap-analysis-and-build-plan.md) §5, and **its Done-when lines are the ones that count**. ETA: wave 2 merged by 18:00 on 19 Nov; QA-R4 and the Advisor's co-sign by 15:00 on 20 Nov; the CEO pack by 20:00 on 20 Nov. Wave 1 times above are provisional. Nothing is called complete until this list is closed.

| ID | Item | Owner | Gate | Status |
|---|---|---|---|---|
| N1 | Sunday check-in (folds in the Sunday prompt) | Planner Engineer (core), iOS Interface Engineer (screen) | C1 | done: core (#103), screen with pain lines (#114), Sunday check-in uses next week's brisk walk (#118). Known limit: a check-in before the programme start returns an empty card (not the CEO's case) |
| N2 | "What changed and why" card | Coach Engineer (core), iOS Interface Engineer | C1 | done: core (#98), card on the N1 screen (#114) |
| N3 | Settings → Preferences: every survey module, re-plan from tomorrow | iOS Interface Engineer, Planner Engineer | — | done: core (#100), Preferences screen (#102); notifications honour a pending edit in #117 |
| N4 | Ask when needed: shop before the first list, office food on the first office day | Planner Engineer, iOS Interface Engineer | N3 | done: core (#107), question screens (#119, with QA-R3-3 social-meal header) |
| N5 | Grocery: send to Reminders, in-store mode, delivery reminder | iOS Interface Engineer, Planner Engineer | N4 | done: delivery reminder (#107), Send to Reminders and in-store mode (#110) |
| N6 | Recipe variety: no dinner repeats within 3 weeks | Researcher (Advisor reviews) | — | done (#97) |
| N7 | Photos: ghost outline, on-device alignment check, compare view, photo-day notification | iOS Interface Engineer | — | done: core (#101), photo-day notification (#112), camera, compare, waist and photo-day route (#122, 67/67) |
| N8 | Easing back after a break | Coach Engineer (moved 18 Nov) | C1 | done: core (#98), line on the N1 screen (#114), UI test (#113) |
| N9 | Ease budget: tap and time budget per job, UI tests, app icon | Product Designer (spec), Coach Engineer (job tests, icon PNG), iOS Interface Engineer | — | done: spec (#93), helper (#104), D2/D6 and icon PNG (#120), F1b (#122), F1 (#124), W2 and A2 (#123). Deferred: Icon Composer `.icon` and four iOS 26 appearances (needs a Mac with Icon Composer) |
| N10 | Checkpoint notification and Hyde Park run loops | Planner Engineer, Researcher (loops) | — | done: loops (#97), checkpoint notification (#107), tap routing (#106), UI test (#113) |
| N9a | Office lunch row on Today's timeline (new TimelineItem `.lunch`) | Planner Engineer (core), Coach Engineer (screen) | N9 spec | done (#111, 55/55 UI tests). Ruling: system Menu rows are exempt from the E6 44 pt floor |
| N9b | Shopping becomes its own tab (MealsUITests move from the segment) | iOS Interface Engineer | after C4, N4, N5 | done (#123, 70/70; delivery reminder opens the Shopping tab) |
| N11 | Amazon basket spike (staples only; cut first if anything slips) | Planner Engineer, Researcher | N5 | staples list done (#97); basket deferred (#108: needs an Associates tag on a deprecated API) |
| N12 | Notification taps open the right screen (W1, W5, F1, K3, delivery, checkpoint, photo day) | Coach Engineer | — | done (#106); photo-day tap opens the camera (#122) |
| QA-R4 | Full round on one build, reported from the user's side | Head of QA (Advisor co-signs) | all | tests in CI (#117, with the N3 pending-edit notification fix); main final at f8435af; round 20 Nov 09:00–15:00 |

**Wave 2 status (19 Nov, 02:00):** every item merged except N11's basket (deferred, #108). Main is final for QA-R4 at `f8435af` (70 UI tests green).

**Known simulator flakes** (each passed on its one allowed re-run, none touched by the PR's diff; iOS investigates if one recurs): AlarmPermissionUITests:137 (SpringBoard alarm alert, #119), WorkoutPlayer Live Activity (#122), Onboarding:50 timing (#122).

**Merge order by screen** (to avoid conflicts; rebase on main before asking for merge): Today: C2 → N1 → N2. Meals: C3/C4 → N4 → N5 → N6 → N11. Progress: N2 → N7. Settings (N3) merges before N4. The Head of Engineering merges one screen's PR at a time.

**Cut order if it slips:** N11, N10, in-store mode (N5), the compare slider (N7).

**Still cut:** the evening meal check (meals stay pre-ticked; the coach steers by the scale) and the mood check (replaced by the N1 check-in's energy, sleep and pain). The photo ghost outline returns in N7.

## Current mode: Gate 2 review · all of M1–M4 built (QA round 2 PASS on `6332a80`, 18 Nov; Advisor co-signed; pack in `docs/review/ceo-review-pack.md`)

| ID | Item | Owner | Branch | Areas | Label | Status | 🙋 CEO hands |
|---|---|---|---|---|---|---|---|
| M0-01 | Repository layout, board, decisions | Head of Engineering | `claude/project-thread-cl2ypb` | repo root, docs/ | docs | done (PR #1) | — |
| M0-02 | Xcode project: app + Live Activity targets linking CoachCore | Planner Engineer | `claude/project-thread-3n9z3c` | App/, LiveActivity/, Shared/, ci_scripts/ | core | done (PR #2) | — |
| M0-12 | GitHub Actions CI: build for the iOS 26 simulator, run CoachCore tests, save spike-screen screenshots | Planner Engineer | — | .github/workflows/ | core | done (PR #13; first compile green) | — |
| M0-04 | S1 · Alarms (code and simulator now; on-phone deferred to payment) | Planner Engineer | `claude/project-thread-3n9z3c` | App/, CoachCore/Planner | core | code done (PR #8, #10); simulator check pending; device test deferred | — |
| M0-05 | S1b · Reconcile on open (code now; TestFlight update test deferred to payment) | Planner Engineer | `claude/project-thread-3n9z3c` | CoachCore/Planner, App/ | core | code done (PR #10); simulator check pending; device test deferred | — |
| M0-06 | S3 · Live Activity timer with voice cues (simulator now; on-phone deferred to payment) | iOS Interface Engineer | `claude/project-thread-buqy8y` | LiveActivity/, App/ | interface | code done (PR #7); simulator check pending; device test deferred | — |
| M0-07 | S2 · Calendar route chosen | Head of Engineering | `claude/project-thread-cl2ypb` | docs/decisions.md | docs | done (PR #1) | — |
| M0-08 | S4 · GIFs found for all ~40 exercises | Training and Nutrition Researcher | Researcher thread (PR #3) | Content/exercises/, docs/ | docs | done (PR #3) | — |
| M0-09 | Cloud sessions can run `swift test` | Head of Engineering | — | project environment | docs | deferred to Gate 2 (needs CEO settings change; CI covers it) | — |
| M0-10 | Gate 0a pack (internal: QA + Advisor sign-off) | Head of Engineering | — | docs/spikes/ | docs | done (gate-0.md) | — |
| M0-11 | In-app "Spike tests" screen (one-tap buttons for S1, S1b, S3) | iOS Interface Engineer | `claude/project-thread-buqy8y` | App/ | interface | done (PR #7) | — |
| M0-03 | S0 · Pipeline: push → Xcode Cloud → TestFlight → phone | Planner Engineer | `claude/project-thread-3n9z3c` | ci_scripts/, Xcode Cloud | core | **deferred to payment** (hook merged PR #5) | — |

Order now: M0-12 (first real compile) → simulator checks of M0-04, M0-05 and M0-06 → M0-10 → Gate 0a. M1 design and content (M1-01 to M1-03) start now in parallel, so code can follow Gate 0a straight away.

## Open QA items (updated 17 Nov, afternoon)

| ID | Item | Owner | Due |
|---|---|---|---|
| QA-5b | One UI-test shot backgrounded mid-rest (Live Activity) | iOS Interface Engineer | in review (cleared by QA-19, PR #58) |
| QA-19 | Leftover Live Activities ended at launch (also clears QA-5b) | iOS Interface Engineer | in review (PR #58) |
| QA-20 | Timeline row follows a weather swap (A6) | iOS Interface Engineer | in review (PR #58) |
| E13 check | Verify start week and passed-session moves on main (PR #40, #48, #56) | Head of QA | Gate 1 |

Closed: QA-10, QA-13 (PR #38); QA-15, QA-16, QA-17 (PR #48); QA-18 moved sessions hold until their slot ends (PR #56).
Earlier closed: QA-1 UI, QA-5, QA-6, QA-8, M0-11 hide (PR #32, #34); QA-9, QA-11, QA-12 (PR #39, QA re-check 17 Nov). QA-7 deferred to payment.

## Done when

### M0-01 · Repository layout, board, decisions
- [ ] Folders match plan §13: `App/`, `LiveActivity/`, `CoachCore/` (Swift package, test target), `Content/{programmes,exercises,recipes}`, `ci_scripts/`, `docs/handoffs/`.
- [ ] `CoachCore/Package.swift` imports nothing but Foundation-level code and declares a `CoachCoreTests` target.
- [ ] `docs/board.md` lists every M0 item from plan §7 with one owner and 2–5 Done when lines.
- [ ] `docs/decisions.md` records the CEO's 2026-11-16 decisions.
- [ ] No secrets, health data or photos in the repo.

### M0-02 · Xcode project
- [ ] `HealthCoach.xcodeproj` is committed, with an iOS 26 app target and a Live Activity widget extension, using the bundle IDs in decisions E1.
- [ ] The app links the local `CoachCore` package and its scheme's test action runs `CoachCoreTests`.
- [ ] `ci_scripts/` sits where Xcode Cloud finds it, and the project builds for an iOS 26 simulator with automatic signing and no committed certificates or keys.
- [ ] `NSAlarmKitUsageDescription`, `NSSupportsLiveActivities` and `ITSAppUsesNonExemptEncryption = NO` are set in the app's Info.plist, so TestFlight never stalls on export compliance.
- [ ] Merged to `main` before any other M0 code item, and the Setup Desk told it is there.

### M0-03 · S0 Pipeline to the phone
- [ ] A commit merged to `main` produces a TestFlight build on the CEO's iPhone with no CEO steps after the one-off setup.
- [ ] Push-to-installed time and Xcode Cloud minutes per build are written in `docs/spikes/s0-pipeline.md`, with the monthly total checked against the 25 included hours.
- [ ] A weekly scheduled Xcode Cloud build exists (Setup Desk Part B), so the 90-day TestFlight expiry never bites.
- [ ] A failing CoachCore test fails the Xcode Cloud build and nothing reaches TestFlight.
- 🙋 Setup Desk checklist Parts A–C: Apple Developer Program, Xcode on the Mac, Xcode Cloud workflow and app record (E1 bundle ID), TestFlight with automatic updates.

### M0-04 · S1 Alarms
- [ ] "Set test alarms" (M0-11) asks for alarm permission and registers 14 test alarms through AlarmKit, the first 2 minutes ahead.
- [ ] That alarm fires and sounds with the phone locked, on Silent and in a Focus mode.
- [ ] The per-app AlarmKit limit and anything else learnt is written in `docs/spikes/s1-alarms.md`.
- [ ] The schedule-to-register logic sits in CoachCore behind a protocol, with unit tests; AlarmKit calls stay in the app.
- 🙋 Setup Desk Part D1.

### M0-05 · S1b Alarms survive a TestFlight update
- [ ] With alarms registered by build N, installing build N+1 through TestFlight leaves them registered, or the gap is recorded in `docs/spikes/s1-alarms.md`.
- [ ] On every app open the app compares registered alarms against the plan and re-sets any that are missing (CoachCore reconcile logic, unit-tested for none missing, some missing, all missing).
- [ ] The Spike tests screen (M0-11) shows a warning until the reconcile has run, then "all alarms set".
- [ ] Planned alarm IDs persist across launches and updates, and an empty or failed plan load never cancels registered alarms (CoachCore unit test). The spike screen can clear the test alarms.
- 🙋 Setup Desk Part D2.

### M0-06 · S3 Live Activity timer
- [ ] "Start test timer" (M0-11) starts a 90-second rest timer that shows a countdown on the lock screen and in the Dynamic Island, and keeps counting while locked.
- [ ] Voice cues ("3, 2, 1, go") play through headphones at the end of the rest with the screen locked, and duck rather than stop music.
- [ ] The Live Activity ends cleanly when the timer finishes or is cancelled; nothing is left on the lock screen.
- [ ] Results and any limits are written in `docs/spikes/s3-live-activity.md`.
- 🙋 Setup Desk Part D3.

### M0-07 · S2 Calendar route
- [ ] `docs/decisions.md` records the route: the Sunday prompt by default, never forward work invites (D5, 2026-11-16).
- [ ] The plan's later option (read iPhone Calendar busy times only, if IT allows) is noted as deferred, with no M0 work.

### M0-08 · S4 Exercise GIFs
- [ ] `Content/exercises/` lists every exercise the Phase 1–3 programmes need (~40), each with a front or side GIF source.
- [ ] Each exercise has three callout slots (setup, movement, common mistake); text can follow in M1.
- [ ] ExerciseDB V1 licence terms are summarised in `docs/spikes/s4-gifs.md`, and any exercise without a GIF has a named substitute.
- [ ] No paid service or API key is used.

### M0-09 · Cloud sessions can run `swift test`
- [ ] The project's cloud environment allows `download.swift.org` (or has Swift preinstalled), so engineers' cloud sessions can install a Swift toolchain.
- [ ] `cd CoachCore && swift test` passes in a cloud session.
- 🙋 Setup Desk: in Project settings → Environment, add a cloud environment whose network access allows `download.swift.org` (package managers left ticked).

### M0-11 · Spike tests screen
- [ ] One screen, reachable from the app's first screen, with "Set test alarms", alarm status (S1b) and "Start test timer".
- [ ] Each test is one tap, and the result is shown on screen in plain words (for example "14 alarms set, next at 07:02").
- [ ] The screen is debug-only scaffolding, removed or hidden behind Settings before Gate 1.

### M0-12 · GitHub Actions CI
- [ ] Every push to a PR and to `main` builds the app and Live Activity for an iOS 26 simulator on a GitHub-hosted macOS runner, with signing off.
- [ ] The same run executes `swift test` for CoachCore; a red build or failing test blocks merge.
- [ ] The run uploads simulator screenshots of the Spike tests screen and the Live Activity as artefacts.
- [ ] Monthly macOS minutes are estimated against the free private-repo allowance; there is no paid plan and the spending limit stays £0.

### M0-10 · Gate 0a pack
- [ ] One page in `docs/spikes/gate-0.md`: what the simulator proved and what is deferred to payment, with screenshots.
- [ ] The CEO can approve Gate 0 from that page in under 5 minutes, with one recommendation marked.


## M1–M4 items

Device-only Done when lines from plan §7 are rewritten as simulator or UI-test checks; the device version joins the deferred list.

| ID | Item | Owner | Label | Status |
|---|---|---|---|---|
| M1-01 | Data model: versioned profile record (SwiftData), programme and exercise JSON schemas, content validation tests | Planner Engineer | core | done (PR #21) |
| M1-02 | Phase 1 programme (`phase-1.json`, weeks 1–6 ramp) and callout text for all 44 exercises | Researcher (Advisor reviews) | docs | done (PR #19) |
| M1-03 | Design: Today, workout player, run-walk, onboarding confirm | Product Designer (Advisor critiques, max 2 rounds) | interface | done (PR #18) |
| M1-04 | Onboarding confirm, pre-filled with decision E6 defaults | iOS Interface Engineer | interface | done (PR #22) |
| M1-05 | Today screen: today's session and timeline | iOS Interface Engineer | interface | done (PR #22) |
| M1-06 | Workout player: GIF, three callouts, rest timer Live Activity, voice countdown, tap rep counter, one-tap "done as prescribed" | iOS Interface Engineer | interface | done (PR #22) |
| M1-07 | Run-walk player: guided intervals with voice cues, building to 5 km | iOS Interface Engineer | interface | done (PR #22) |
| M1-08 | Progression: reps → sets → tempo → weight, dumbbell-limit flag, drop to 2 strength sessions after two low recovery checks | Planner Engineer | core | done (PR #27) |
| M2-01 | Week planner: Sunday prompt answers, session placement around basketball and office days, wake time | Planner Engineer | core | done (PR #28) |
| M2-02 | 14-day alarm schedule through the reconcile, "tomorrow changed" re-plan, missing-alarm warning on Today | Planner Engineer | core | done (PR #30; Today warning UI with iOS Interface Engineer) |
| M2-03 | Weather swap (Open-Meteo, no key) when the morning brief opens | Planner Engineer | core | done (PR #39; Advisor to confirm thresholds before Gate 1) |
| M2-04 | Health: weight 7-day trend and steps (read-only) | Planner Engineer | core | done (PR #39) |
| M2-05 | Sunday prompt screen, full Today timeline, local notifications with quiet hours 22:30–06:00 | iOS Interface Engineer | interface | done (PR #38; E13 core PR #40, replay PR #48, QA-18 PR #56) |
| M3-01 | Recipes (box nights, breakfasts, home lunches, Sunday cook; 2 portions, no raw fish, no batch cooking) and office lunch list | Researcher (Advisor reviews) | docs | done (folded into PR #59; #44 closed) |
| M3-02 | Meal plan and tracking: pre-ticked meals, day band and extras (evening "anything different?" and social meals cut, re-plan 17 Nov) | Planner Engineer | core | done (PR #59) |
| M3-03 | Top-up list: merged quantities, aisle order, staples, search links to the default shop | Planner Engineer | core | done (PR #59) |
| M3-04 | Meals, shopping and lunch screens | iOS Interface Engineer | interface | done (PR #66; QA-29 aisle names and 44 pt ticks PR #70) |
| M4-01 | Rules engine: calories from trend, load from logs, volume from recovery, stall flag | Coach Engineer | core | done (PR #53) |
| M4-02 | Claude summary and share; clipboard import of a versioned block, rejected safely when bad | Coach Engineer | core | done (PR #53, import button PR #54; A17 plan wiring PR #60) |
| M4-03 | Progress view, photos every 2 weeks, "Ask the coach now" (ghost outline and mood check cut, re-plan 17 Nov) | iOS Interface Engineer | interface | done (PR #57) |
| M2-06 | "Tomorrow changed" button on Today: one tap opens tomorrow's answers, saves, and re-plans that one day's alarm and notifications (core `AlarmSchedule.replacingDay`, M2-02) | iOS Interface Engineer | interface | done (PR #72; moved into the ⋯ menu by UI-12, PR #76; basketball skip is a follow-up for the Planner Engineer) |
| M0-11b | Hide the Spike tests wrench everywhere except the alarm spike test (`-spikeAlarms`) and the spike screenshot modes, so Today and Onboarding shots for the review show no engineering tools | iOS Interface Engineer | interface | done (PR #72) |
| UI-12 | Declutter pass: one ⋯ menu on Today, fewer cards, quieter lists (`docs/design/ui-12-declutter.md`) | Product Designer, then iOS Interface Engineer | interface | done (spec PR #74, build PR #76) |
| QA-R2 | Combined Gate 1 and Gate 2 QA round on one build | Head of QA (Advisor co-signs) | docs | done: PASS on `6332a80` (PRs #73, #75, #77, fixes #78, report #80) |
| G2-01 | Gate 2 pack (`docs/review/ceo-review-pack.md`) | Head of Engineering | docs | done (ready for the CEO at 20:00, 18 Nov) |

### Done when (M1–M4)

**M1-01** · The app never crashes when the store won't open: it recovers and shows a one-line notice. SwiftData is versioned (review of PR #21) · Profile record and content files decode with a version; a newer or broken file is rejected with a plain message · every file in `Content/` is validated by a CoachCore test · `exercises.json` moves from schemaVersion 0 to 1.
**M1-02** · Weeks 1–6 match plan §2 (3 strength + run-walk + basketball; second run from week 4; light legs until week 4; nothing on Wednesday) · every exercise has its three callouts · Advisor's points answered as accepted, changed or rejected in the PR.
**M1-03** · Mock-ups for the four screens, each usable one-handed with a big next and done · Advisor critique folded in within 2 rounds · open taste decisions listed for Gate 2, not asked.
**M1-04** · A simulator UI test confirms onboarding in under 5 minutes of taps, with every default pre-filled · the result is stored in the profile record.
**M1-05** · Today shows the right session for any date in weeks 1–6 (UI test across 7 days).
**M1-06** · Rest comes from `phase-1.json` per block (75 s paired main lifts, 60 s single-leg, 45 s arm and shoulder accessories, 30–45 s core), with 90 s only as a fallback; a CoachCore test checks that every Phase 1 block has a rest value (Advisor, Gate 0a) · a voice heads-up at 10 s left names the next exercise and weight ("10 seconds. Next, one-arm row, 12 kilos"), ducking the music and never pausing it (Advisor, Gate 0a) · A UI test completes a full Phase 1 session touching only "next" and "done" · the GIFs are bundled (no network) · the Live Activity starts and ends with each rest (simulator screenshot).
**M1-07** · The week 1 run-walk (1 min jog, 1 min walk × 10) plays with voice cues in the simulator, and later weeks build towards 5 km.
**M1-08** · CoachCore tests prove the next session's loads change correctly after logging, including the dumbbell-limit flag at 24 kg and the drop to 2 sessions.
**M2-01** · CoachCore tests place sessions correctly for at least 6 office-day patterns, never on Wednesday · wake time = first commitment − commute − shower − session − buffer, protecting 7.5 h of sleep.
**M2-02** · The reconcile keeps 7–14 days of alarms registered across simulated app opens, with no owner action · "tomorrow changed" re-plans one day only · the empty-plan guard holds · zero upcoming alarms always shows a warning on Today, never "all set" (QA-1) · an XCUITest taps Allow, registers 14 alarms and sees "All alarms set (14)" after relaunch (QA-2).
**M2-03** · A bad-weather forecast swaps an outdoor run for an indoor session of the same length, without moving the wake time · works offline (no swap, no error).
**M2-04** · The 7-day weight average reads from Health in the simulator (sample data) · no health data leaves the phone.
**M2-05** · The Sunday prompt takes under 20 seconds of taps in a UI test · no notification fires in quiet hours (unit-tested).
**M3-01** · The box-night calories and protein entry · 3–4 breakfasts, home lunches and 1 Sunday cook, all 2 portions, with calories and protein · 5–6 lunch orders within 8 minutes' walk of St James's Market.
**M3-02** · A simulated week of eating needs no questions (evening question cut, re-plan 17 Nov) · daily protein is planned at about 160 g, and calories match the phase target.
**M3-03** · One merged weekly list sorted by aisle · staples are ticked once · each item has a search link to the default shop (E5).
**M3-04** · Screens walked in the simulator; the lunch card suggests one order on office days.
**M4-01** · A simulated 2-week stall raises a flag · calories adjust from the 7-day trend within safe bounds (Advisor-reviewed).
**M4-02** · An imported Claude block changes next week's plan · a malformed or wrong-version block is rejected with a plain message, and last week's plan stays (CoachCore tests).
**M2-06** · On Today, "Tomorrow changed" opens tomorrow's Sunday-prompt answers only; saving re-plans that one day through `AlarmSchedule.replacingDay`, every other day's alarm is untouched · a UI test changes tomorrow's wake time and sees tomorrow's timeline and the alarm count update, with today unchanged.
**M0-11b** · Today and Onboarding show no wrench in any review screenshot or ordinary UI test · `AlarmPermissionUITests` still reaches Spike tests with `-spikeAlarms` · release builds never show it.
**M4-03** · Photo day every 2 weeks with a ghost outline (simulator camera roll) · skipping mood changes nothing · "Ask the coach now" builds a summary and opens the share sheet.
**G2-01** · Full end-to-end QA round clean on one fixed build · a demo walkthrough (screenshots or recording) of a typical week · the deferred list, with the open taste decisions · one recommendation on payment.

## Done

- 2026-11-19 · Wave 2: N1 (#114, #118) · N2, N8 (#114) · N3 fix (#117) · N4 (#119) · N5 (#110) · N7 (#122) · N9 (#120, #124) · N9a (#111) · N9b (#123) · QA-R3 PASS (#115) · QA-R4 tests (#117)
- 2026-11-17 · M3-01, M3-02, M3-03 · PR #59 (meal plan, day band ±150 kcal, floor 1,700, protein ≥150 g, extras; top-up list; folds in #44) · M4-03 · PR #57 · M2-05 · PR #38 · QA-18 · PR #56 · M4-01, M4-02 · PR #53, #54 · QA-15/16/17 · PR #48 · Gate 1 §A fixtures · PR #55
- 2026-11-16 · M1-04, M1-05, M1-06, M1-07 · PR #22 (all M1 screens; QA M1 sanity check passed, PR #31) · M2-02 · PR #30 (14-day wake alarms; AlarmKit burst refusal fixed with retry and backoff; reduced week drops Thursday's alarm)
- 2026-11-16 · M2-01 · PR #28 (week planner, CoachCore only; decision E10) · M1-08 · PR #27 (progression engine, SwiftData store recovery and SchemaV1, QA-2 alarm XCUITest) · M1-01 · PR #21
- 2026-11-16 · M1-02 · PR #19 (Phase 1 programme, all callouts; Advisor signed off) · M1-03 · PR #18 (15 screens; taste decisions held for Gate 2)
- 2026-11-16 · M0-12 · PR #13 (Linux core tests + macOS simulator build, both green on the first compile; merge on green by process, as GitHub Free has no branch protection)
- 2026-11-16 · QA test plan and Gate 0a checklist · PRs #15, #16 · M0-06 no-audio fallback · PR #14 · screenshot modes · PR #11
- 2026-11-16 · M0-04/05 part 2 · PR #10
- 2026-11-16 · M0-06 (code), M0-11 · PR #7 (Spike tests screen, Live Activity timer, voice cues; not compiled yet)
- 2026-11-16 · M0-04/05 part 1 · PR #8 (CoachCore reconcile + S1 schedule, unit-tested; AlarmKit registrar)
- 2026-11-16 · M0-03 (part) · PR #5 (CoachCore tests run before every archive; pipeline itself waits on Setup Desk Part B)
- 2026-11-16 · M0-08 · PR #3 (44 exercises; GIFs personal-use only, bundle in M1, clear licence before any wider release; rear three-quarter angle on bar exercises accepted)
- 2026-11-16 · M0-02 · PR #2 (not compiled yet: first Xcode Cloud build is the compile check)
- 2026-11-16 · M0-01, M0-07 · PR #1 (Head of Engineering reviewed against Done when; `swift test` not yet run, see M0-09)
