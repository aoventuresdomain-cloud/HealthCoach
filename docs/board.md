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
| **Gate 2 pack** | Full QA round, a release-ready simulator build, a demo walkthrough, the deferred list, and one recommendation on payment | Head of Engineering | 27 Dec (end of week 6) |
| **Gate 2** | CEO reviews and decides how to move | **CEO** | after 27 Dec |
| Run | Phase 2 and 3 programmes as data | Researcher | before weeks 7 and 15 |

**Cut rule:** if any milestone slips more than a week, cut M3 extras first (in-store mode, delivery reminder, lunch swipe), then M4 photos.

**Deferred to payment (built, not provable until the CEO says when):** S0 pipeline to the phone (M0-03). S1 alarms ringing locked, on Silent and in Focus. S1b alarms surviving an update. S3 lock-screen timer and voice through headphones while locked. Real Health scale data. Backup Clock alarm for the first week on the app. All need ~45 min of setup and ~15 min of on-phone tests once paid; the Setup Desk checklist already covers them (Parts A–D). **Risk:** alarm and timer code ship unproven on a device; M2's wake alarms depend on it. If the device tests fail later, only the AlarmKit and ActivityKit layer is reworked, because CoachCore is device-independent.

## Current mode: build cycle · M1 (Gate 0a passed 2026-11-16: QA round 1 on `be49d2f`, Advisor co-signed; pack in `docs/spikes/gate-0.md`)

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
| M1-04 | Onboarding confirm, pre-filled with decision E6 defaults | iOS Interface Engineer | interface | in review (PR #22) |
| M1-05 | Today screen: today's session and timeline | iOS Interface Engineer | interface | in review (PR #22) |
| M1-06 | Workout player: GIF, three callouts, rest timer Live Activity, voice countdown, tap rep counter, one-tap "done as prescribed" | iOS Interface Engineer | interface | in review (PR #22) |
| M1-07 | Run-walk player: guided intervals with voice cues, building to 5 km | iOS Interface Engineer | interface | in review (PR #22) |
| M1-08 | Progression: reps → sets → tempo → weight, dumbbell-limit flag, drop to 2 strength sessions after two low recovery checks | Planner Engineer | core | done (PR #27) |
| M2-01 | Week planner: Sunday prompt answers, session placement around basketball and office days, wake time | Planner Engineer | core | done (PR #28) |
| M2-02 | 14-day alarm schedule through the reconcile, "tomorrow changed" re-plan, missing-alarm warning on Today | Planner Engineer | core | in progress |
| M2-03 | Weather swap (Open-Meteo, no key) when the morning brief opens | Planner Engineer | core | todo |
| M2-04 | Health: weight 7-day trend and steps (read-only) | Planner Engineer | core | todo |
| M2-05 | Sunday prompt screen, full Today timeline, local notifications with quiet hours 22:30–06:00 | iOS Interface Engineer | interface | todo |
| M3-01 | Recipes (box nights, breakfasts, home lunches, Sunday cook; 2 portions, no raw fish, no batch cooking) and office lunch list | Researcher (Advisor reviews) | docs | todo |
| M3-02 | Meal plan and tracking: pre-ticked meals, evening "anything different?", 2 untracked social meals | Planner Engineer | core | todo |
| M3-03 | Top-up list: merged quantities, aisle order, staples, search links to the default shop | Planner Engineer | core | todo |
| M3-04 | Meals, shopping and lunch screens | iOS Interface Engineer | interface | todo |
| M4-01 | Rules engine: calories from trend, load from logs, volume from recovery, stall flag | Planner Engineer | core | todo |
| M4-02 | Claude summary and share; clipboard import of a versioned block, rejected safely when bad | Planner Engineer | core | todo |
| M4-03 | Progress view, photos every 2 weeks with a ghost outline, optional mood check, "Ask the coach now" | iOS Interface Engineer | interface | todo |
| G2-01 | Gate 2 pack | Head of Engineering | docs | todo |

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
**M3-02** · A simulated week of eating needs only the evening question · daily protein is planned at about 160 g, and calories match the phase target.
**M3-03** · One merged weekly list sorted by aisle · staples are ticked once · each item has a search link to the default shop (E5).
**M3-04** · Screens walked in the simulator; the lunch card suggests one order on office days.
**M4-01** · A simulated 2-week stall raises a flag · calories adjust from the 7-day trend within safe bounds (Advisor-reviewed).
**M4-02** · An imported Claude block changes next week's plan · a malformed or wrong-version block is rejected with a plain message, and last week's plan stays (CoachCore tests).
**M4-03** · Photo day every 2 weeks with a ghost outline (simulator camera roll) · skipping mood changes nothing · "Ask the coach now" builds a summary and opens the share sheet.
**G2-01** · Full end-to-end QA round clean on one fixed build · a demo walkthrough (screenshots or recording) of a typical week · the deferred list, with the open taste decisions · one recommendation on payment.

## Done

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
