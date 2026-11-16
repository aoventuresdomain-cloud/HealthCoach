# Work board

Kept by the Head of Engineering, the only one who merges. One owner per item. Status: `todo` · `in progress` · `in review` · `done` · `blocked`.
QA label: **core** = full end-to-end round (CoachCore, alarm scheduling, Health, data model, Claude import, pipeline); **interface** = sanity plus a walk of changed screens; **docs** = sanity only. Unlabelled means core.

**🙋 CEO hands** marks steps that need the owner's hands. Engineers never ask the CEO; the Setup Desk batches every 🙋 step into one checklist, verifies the result and tells the owner.

## Current mode: build cycle · Milestone M0 (setup and spikes) → Gate 0

Gate 0 (CEO approves): spikes S0, S1, S1b and S3 pass or their fallbacks are accepted; S2 and S4 closed.

| ID | Item | Owner | Branch | Areas | Label | Status | 🙋 CEO hands |
|---|---|---|---|---|---|---|---|
| M0-01 | Repository layout, board, decisions | Head of Engineering | `claude/project-thread-cl2ypb` | repo root, docs/ | docs | in review | — |
| M0-02 | Xcode project: app + Live Activity targets linking CoachCore | Planner Engineer | — | App/, LiveActivity/, ci_scripts/ | core | todo | — |
| M0-03 | S0 · Pipeline: push → Xcode Cloud → TestFlight → phone | Planner Engineer | — | ci_scripts/, Xcode Cloud | core | todo | yes |
| M0-04 | S1 · Alarms fire locked, on Silent and in Focus | Planner Engineer | — | App/, CoachCore/Planner | core | todo | yes |
| M0-05 | S1b · Alarms survive a TestFlight update, or are re-set on open | Planner Engineer | — | CoachCore/Planner, App/ | core | todo | yes |
| M0-06 | S3 · Live Activity rest timer with voice cues | iOS Interface Engineer | — | LiveActivity/, App/ | interface | todo | yes |
| M0-07 | S2 · Calendar route chosen | Head of Engineering | `claude/project-thread-cl2ypb` | docs/decisions.md | docs | in review | — |
| M0-08 | S4 · GIFs found for all ~40 exercises | Training and Nutrition Researcher | — | Content/exercises/, docs/ | docs | todo | — |
| M0-09 | Cloud sessions can run `swift test` | Head of Engineering | — | project environment | docs | blocked | yes |
| M0-10 | Gate 0 pack for the CEO | Head of Engineering | — | docs/spikes/ | docs | todo | — |
| M0-11 | In-app "Spike tests" screen (one-tap buttons for S1, S1b, S3) | iOS Interface Engineer | — | App/ | interface | todo | — |

Order: M0-01 → M0-02 (merge to `main` first, then tell the Setup Desk: it holds checklist Part B until the skeleton is in) → M0-03 → (M0-04, M0-06, M0-11 in parallel) → M0-05 → M0-10. M0-08 runs alongside from now. M0-09 is independent.

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

### M0-10 · Gate 0 pack
- [ ] One page in `docs/spikes/gate-0.md`: each spike as pass or fail, with the fallback for any fail.
- [ ] The CEO can approve Gate 0 from that page in under 5 minutes, with one recommendation marked.

## Done

_Nothing merged yet._
