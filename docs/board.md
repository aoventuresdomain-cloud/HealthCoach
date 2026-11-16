# Work board

Kept by the Head of Engineering, the only one who merges. One owner per item. Status: `todo` · `in progress` · `in review` · `done` · `blocked`.
QA label: **core** = full end-to-end round (CoachCore, alarm scheduling, Health, data model, Claude import, pipeline); **interface** = sanity plus a walk of changed screens; **docs** = sanity only. Unlabelled means core.

**🙋 CEO hands** marks steps that need the owner's hands. Engineers never ask the CEO; the Setup Desk batches every 🙋 step into one checklist, verifies the result and tells the owner.

## Roadmap (re-sequenced 2026-11-16: paid Apple account on hold)

The CEO is training from the paper Week 1 plan meanwhile. Until the paid account, nothing reaches the phone. Work is proven by CI builds, tests and simulator screenshots.

| Step | Purpose | Needs from the CEO |
|---|---|---|
| **M0a** · Setup and spikes, free | Repo, CI that compiles the app and runs every test, spike code checked in the simulator | Nothing. Optional: allow `download.swift.org` in the cloud environment (M0-09) |
| **Gate 0a** | Approve building on: app compiles, tests green, spike screens shown in simulator screenshots | ~5 min to read the Gate 0 pack and say go |
| **M1** · Workout | Onboarding confirm, Phase 1 programme, Today screen, workout player, one-tap logging, progression | Nothing until the gate |
| **Pay trigger** | When M1 runs end to end in the simulator, that is the "material product". Join the Apple Developer Program (~£79) | ~45 min once: Setup Desk Parts A–C |
| **M0b** · Phone spikes | Pipeline to the phone; alarms fire locked, on Silent and in Focus; they survive an update; lock-screen timer with voice | ~15 min: Setup Desk Part D |
| **Gate 0b** | Approve that alarms and the timer work on the real phone, or accept fallbacks | ~5 min |
| **M2** · Planner | Sunday prompt, wake times, 14-day alarms, weather swap, notifications, Health weight and steps | Allow Health on the phone |
| **Gate 1** | Stop using paper; the app runs the week | ~5 min; the stop rule applies if not by end of week 4 |
| **M3** · Meals | Meals around the box, breakfasts, Sunday cook, top-up list, office lunch list | Default shop and delivery slot (one question) |
| **M4** · Coach | Rules engine, stall flag, Claude summary and import, progress view, photos | Nothing |
| **Gate 2** | Checkpoint 1 at week 6: first live Claude review | ~10 min |
| Checkpoints | Weeks 14 and 20; Phases 2 and 3 are content updates | ~10 min each |

Risk of the hold: alarms are the product's riskiest part and stay unproven on a real phone until M0b. M1 doesn't depend on them, and M2 does, so payment must land before M2 starts.

## Current mode: build cycle · M0a → Gate 0a

| ID | Item | Owner | Branch | Areas | Label | Status | 🙋 CEO hands |
|---|---|---|---|---|---|---|---|
| M0-01 | Repository layout, board, decisions | Head of Engineering | `claude/project-thread-cl2ypb` | repo root, docs/ | docs | done (PR #1) | — |
| M0-02 | Xcode project: app + Live Activity targets linking CoachCore | Planner Engineer | `claude/project-thread-3n9z3c` | App/, LiveActivity/, Shared/, ci_scripts/ | core | done (PR #2) | — |
| M0-12 | GitHub Actions CI: build for the iOS 26 simulator, run CoachCore tests, save spike-screen screenshots | Planner Engineer | — | .github/workflows/ | core | todo | — |
| M0-04 | S1 · Alarms (code and simulator now; on-phone in M0b) | Planner Engineer | `claude/project-thread-3n9z3c` | App/, CoachCore/Planner | core | in progress (part 1 PR #8) | M0b |
| M0-05 | S1b · Reconcile on open (code now; TestFlight update test in M0b) | Planner Engineer | `claude/project-thread-3n9z3c` | CoachCore/Planner, App/ | core | in progress | M0b |
| M0-06 | S3 · Live Activity timer with voice cues (simulator now; on-phone in M0b) | iOS Interface Engineer | `claude/project-thread-buqy8y` | LiveActivity/, App/ | interface | in progress (code PR #7) | M0b |
| M0-07 | S2 · Calendar route chosen | Head of Engineering | `claude/project-thread-cl2ypb` | docs/decisions.md | docs | done (PR #1) | — |
| M0-08 | S4 · GIFs found for all ~40 exercises | Training and Nutrition Researcher | Researcher thread (PR #3) | Content/exercises/, docs/ | docs | done (PR #3) | — |
| M0-09 | Cloud sessions can run `swift test` | Head of Engineering | — | project environment | docs | blocked (optional) | yes |
| M0-10 | Gate 0a pack for the CEO | Head of Engineering | — | docs/spikes/ | docs | todo | — |
| M0-11 | In-app "Spike tests" screen (one-tap buttons for S1, S1b, S3) | iOS Interface Engineer | `claude/project-thread-buqy8y` | App/ | interface | done (PR #7) | — |
| M0-03 | S0 · Pipeline: push → Xcode Cloud → TestFlight → phone | Planner Engineer | `claude/project-thread-3n9z3c` | ci_scripts/, Xcode Cloud | core | **on hold until paid** (hook merged PR #5) | M0b |

Order now: M0-12 (first real compile) → M0-04/05 part 2 → simulator checks of M0-04, M0-05 and M0-06 → M0-10 → Gate 0a. M0-03 and the on-phone halves of M0-04, M0-05 and M0-06 move to M0b after payment. M1 items are written up at Gate 0a.

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
- [ ] One page in `docs/spikes/gate-0.md`: what the simulator proved and what waits for the phone (M0b), with screenshots.
- [ ] The CEO can approve Gate 0 from that page in under 5 minutes, with one recommendation marked.

## Done

- 2026-11-16 · M0-06 (code), M0-11 · PR #7 (Spike tests screen, Live Activity timer, voice cues; not compiled yet)
- 2026-11-16 · M0-04/05 part 1 · PR #8 (CoachCore reconcile + S1 schedule, unit-tested; AlarmKit registrar)
- 2026-11-16 · M0-03 (part) · PR #5 (CoachCore tests run before every archive; pipeline itself waits on Setup Desk Part B)
- 2026-11-16 · M0-08 · PR #3 (44 exercises; GIFs personal-use only, bundle in M1, clear licence before any wider release; rear three-quarter angle on bar exercises accepted)
- 2026-11-16 · M0-02 · PR #2 (not compiled yet: first Xcode Cloud build is the compile check)
- 2026-11-16 · M0-01, M0-07 · PR #1 (Head of Engineering reviewed against Done when; `swift test` not yet run, see M0-09)
