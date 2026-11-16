# QA test plan

Owner: Head of QA and Validation · 2026-11-16 · applies until Gate 2 (standing order D7).

**Recommendation:** prove everything we can in CoachCore unit tests and simulator UI tests, keep the phone-only checks on one deferred list, and spend the free macOS CI minutes on builds, UI tests and gate rounds, not on CoachCore tests (move those to a Linux job, 1× minutes).

## 1. What we can and can't prove before payment

| Proved now | How |
|---|---|
| Planner, alarm reconcile, progression, rules engine, import parser, content files | CoachCore unit tests (Swift Testing) |
| App and Live Activity compile for iOS 26 | CI `xcodebuild build`, signing off |
| Screens show the right thing for a given day and state | XCUITest in the iOS 26 simulator, with a fixed clock and fixture data |
| Layout and copy | Simulator screenshots, walked by QA |
| Live Activity starts, shows in the Dynamic Island, ends cleanly | Simulator screenshots (app backgrounded) |

| Deferred to payment (board list) | Why not now |
|---|---|
| Alarms ring locked, on Silent, in a Focus (S1) | Simulator can't lock, has no Silent switch or Focus |
| Alarms survive a TestFlight update (S1b) | Needs TestFlight |
| Lock-screen countdown while locked; voice cues through headphones; music ducks (S3) | `simctl` can't lock; no headphone route in CI |
| Push → TestFlight → phone (S0) | Needs the paid account |
| Real Health scale data | Simulator uses sample data only |

Every device-only Done when line gets a simulator stand-in (decision E7) and a matching line on the deferred list. The deferred list is run as one ~15-minute on-phone round (M0b) once the CEO pays.

## 2. Test layers

**L1 · CoachCore unit tests.** Every rule with a number or a date in it has a test: wake-time maths, session placement, quiet hours, progression steps, the 24 kg flag, calorie bounds, import accept and reject. Time always comes in as a parameter (`now:`), never `Date()` inside CoachCore. Calendar maths is tested across the UK clock change (last Sunday of March and October) and at midnight.

**L2 · Content validation.** One CoachCore test loads every file in `Content/` (M1-01): it decodes, has the expected `schemaVersion`, every exercise referenced by a programme exists, every exercise has a GIF or named substitute and three callouts, recipes have calories and protein. A bad content file fails CI, so Phase 2 and 3 updates are safe.

**L3 · Build and launch smoke.** CI builds the app and Live Activity, installs on an iPhone Pro simulator, launches, and fails if the app crashes within 10 seconds.

**L4 · Simulator UI tests (XCUITest).** See §3.

**L5 · Screenshots.** CI saves screenshots of every screen state in `-screenshot` modes. QA walks the changed ones on interface PRs and all of them in a full round.

**L6 · On-device round (after payment).** The deferred list above, run from the Spike tests screen and the Setup Desk checklist Part D.

## 3. Simulator UI-test approach

1. **Target.** Add a `HealthCoachUITests` UI test target to `HealthCoach.xcodeproj` and to the shared scheme's test action (Planner Engineer, with M1-01). CoachCoreTests stays in the scheme.
2. **Deterministic launch.** Tests start the app with launch arguments, extending today's `-screenshot` pattern:
   - `-uitest` turns on test mode: in-memory SwiftData store, no network, animations off, the AlarmKit and ActivityKit layers swapped for recording fakes behind the existing CoachCore protocols.
   - `-now 2026-11-23T06:30:00Z` fixes the clock the app passes to CoachCore.
   - `-fixture <name>` loads a named state (for example `week1-monday`, `week4-office-tue-thu`, `stalled-2-weeks`, `alarms-3-missing`) from a test-only JSON file.
   Test mode compiles only in Debug and is ignored in Release, like the Spike tests screen.
3. **Finding things.** Every tappable control and every result line gets an `accessibilityIdentifier` (`today.session.title`, `player.next`, `player.done`, `spikes.setAlarms`). Tests never match on copy, so wording changes don't break them; one copy test per screen checks the key words.
4. **System alerts.** Permission prompts are handled with `addUIInterruptionMonitor`, or avoided in test mode by the fakes. Real AlarmKit in the simulator is tried once at Gate 0a (§6) and recorded.
5. **Time-based flows.** No real waiting: the rest timer, run-walk intervals and the 14-day alarm window run on the injected clock. One test per flow runs at real speed for 10 seconds as a smoke check.
6. **"Only next and done".** M1-06's test taps only `player.next` and `player.done` and fails if any other control was needed. This is the guiding rule as a test.
7. **Evidence.** Each UI test attaches a screenshot at its key step (`XCTAttachment`, kept on failure and success); CI uploads the `.xcresult` bundle.
8. **Size.** Aim for 15–25 UI tests by Gate 2, one per Done when line that names a UI test, plus the onboarding-to-workout happy path. Everything else is L1.

## 4. QA by risk, as practised here

The board label sets the depth. Unlabelled means core.

| Change | QA does |
|---|---|
| Every PR (sanity) | CI **Build and test** green on the PR's last commit; Done when lines answered in the PR; diff has no secrets, health data, photos or network calls to anything but Open-Meteo; Advisor's points answered where the item needed the Advisor. Red blocks merge |
| After each merged batch (sanity) | `main` CI green; screenshots artefact present |
| **interface** | Sanity, plus a walk of the changed screens' screenshots against the mock-ups and the guiding rule (one hand, big next and done, no thinking) |
| **core** | Sanity, then a full round before the next gate or release-ready batch |
| **docs** | Sanity only (CI is skipped for docs; QA reads the diff) |
| Before any gate, at release-ready, or when the CEO asks | Full round |

GitHub Free can't enforce required checks on a private repo, so the Head of Engineering merges only on green. QA spot-checks merged PRs' check status after each batch and raises any merge on red as a major.

## 5. Full round and the QA loop

1. QA names one fixed commit SHA on `main` and asks the Head of Engineering to freeze merges to blocker and major fixes plus test-only changes.
2. QA runs CI on that SHA with `workflow_dispatch` (all UI tests, all screenshots).
3. QA works through the gate's checklist line by line and writes results in `docs/qa/rounds/<date>-<round>.md`: pass, fail (with bug), or deferred.
4. Blockers and majors go live to the Head of Engineering, one line each, and to the Chief of Staff as one line. Minors are batched into the round report.
5. Fixes land; QA re-checks each fix on the new SHA, then reruns the round's failed lines plus a smoke of the rest. The loop closes when a round is clean.

**Severity**

| Level | Meaning | Example |
|---|---|---|
| Blocker | Wrong training or alarm outcome, data loss, or crash on a main path | Reconcile cancels the owner's alarms; app crashes on Today |
| Major | A Done when line fails, or the CEO would have to think or do admin | Workout needs a tap other than next or done |
| Minor | Wrong but harmless, with a workaround | Copy truncated on the smallest phone |
| Trivial | Cosmetic | Spacing |

**Bug report (to the Head of Engineering):** title · severity · board item and Done when line · SHA · steps (launch arguments) · expected · actual · evidence (screenshot or test name).

## 6. CI minutes

The free plan gives about 200 macOS minutes a month (10× multiplier, £0 limit). The PR #13 estimate is 8–10 minutes a run, so about 20 runs. UI tests will add 5–8 minutes. To stay inside it:

- **Move `swift test` to an `ubuntu-latest` job** (CoachCore is Foundation-only by design). It runs on every push at 1× and costs ~2 minutes of the 2,000; CoachCore-only PRs then need no macOS run at all. Recommended to the Planner Engineer as a follow-up to M0-12.
- UI tests run on `main`, on `workflow_dispatch` and on PRs labelled core or interface that touch `App/`, not on every push.
- A full round costs one dispatched run (~15 minutes). Budget: Gate 0a, Gate 1, Gate 2 and up to three re-runs ≈ 90 minutes.
- QA logs measured minutes in `docs/spikes/m0-12-ci.md` and warns the Head of Engineering at 70% used in a month.

## 7. Coverage map to Gate 2

| Item | L1 unit | L2 content | L4 UI test | L5 screenshots | Deferred |
|---|---|---|---|---|---|
| M1-01 data model | decode, versions, reject newer | all files | — | — | — |
| M1-02 Phase 1 programme | weeks 1–6 rules (no Wednesday, legs light to week 4, second run from week 4) | yes | — | — | — |
| M1-04 onboarding | profile saved | — | defaults pre-filled, confirm in few taps | yes | — |
| M1-05 Today | session for date | — | 7 days of week 1 | yes | — |
| M1-06 workout player | log "as prescribed" | GIFs bundled | full session with only next and done; rest starts Live Activity | yes | lock screen, voice while locked |
| M1-07 run-walk | interval schedule to 5 km | — | week 1 plays on injected clock | yes | voice through headphones |
| M1-08 progression | reps → sets → tempo → weight, 24 kg flag, drop to 2 sessions | — | — | — | — |
| M2-01 planner | 6+ office-day patterns, wake-time formula, 7.5 h sleep | — | — | — | — |
| M2-02 alarms | 7–14 day window over simulated opens, one-day re-plan, empty-plan guard | — | missing-alarm warning on Today | yes | ringing on the phone |
| M2-03 weather | swap rule, offline = no swap | — | — | — | live forecast |
| M2-04 Health | 7-day average maths | — | trend shows from sample data | yes | real scale data |
| M2-05 Sunday prompt | quiet hours 22:30–06:00 | — | prompt in under 20 s of taps | yes | notification delivery |
| M3-01 to M3-04 meals | protein ~160 g, calorie target, merged list by aisle | recipes valid | evening question only | yes | — |
| M4-01 rules engine | stall flag at 2 weeks, safe calorie bounds | — | — | — | — |
| M4-02 Claude import | accept, reject malformed, reject wrong version, last plan kept | — | paste and apply | yes | — |
| M4-03 progress | photo every 2 weeks | — | share sheet opens | yes | camera on phone |

The Advisor reviews the expected values in the training and nutrition tests (M1-02, M1-08, M3-02, M4-01) before they are treated as the truth.

## 8. Gate rounds

- **Gate 0a (internal, ~21 Nov):** checklist in `docs/qa/gate-0a-checklist.md`. Signed by Head of QA and the Advisor.
- **Gate 1 (internal, ~12 Dec):** a simulated week (Sunday prompt to Saturday) runs from the app on the injected clock with no paper, judged against the guiding rule. Checklist written at M2 start.
- **Gate 2 pack (~27 Dec):** full round clean on one fixed build, plus the deferred list for the CEO.
