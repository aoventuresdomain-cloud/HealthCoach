# Gate 0a checklist (internal)

Signed by Head of QA and the Advisor, ~21 Nov 2026. Run as a full round on one fixed `main` SHA (test plan §5). Each line is pass, fail (bug filed) or deferred (on the board's "Deferred to payment" list).

**Gate 0a passes when** every non-deferred line passes, the deferred list is agreed, and the Gate 0a pack (M0-10) reads in under 5 minutes.

Round SHA: `________` · CI run: `________` · Date: `________`

## Pre-checks done 2026-11-16 (static, on `main` at `1bf1f2d`)

| Line | Result |
|---|---|
| M0-02 Info.plist has `NSAlarmKitUsageDescription`, `NSSupportsLiveActivities`, `ITSAppUsesNonExemptEncryption = NO` | pass |
| M0-02 shared scheme's test action runs `CoachCoreTests` | pass |
| M0-05 reconcile tests cover none, some and all missing, and the empty-plan guard | pass (code read; not yet run, CI pending) |
| M0-04 schedule logic in CoachCore behind `AlarmRegistering`, unit-tested; AlarmKit calls only in `App/` | pass (code read) |

## Round lines

### M0-01 · Repository
- [ ] Folders match plan §13 (as amended by E2, E3).
- [ ] `CoachCore` imports Foundation only (grep: no `UIKit`, `SwiftUI`, `AlarmKit`, `HealthKit`, `ActivityKit`, `SwiftData`).
- [ ] No secrets, health data or photos in the repo (grep for keys, tokens, `.p12`, `.mobileprovision`, images outside `Assets.xcassets` and `Content/exercises`).

### M0-02 · Xcode project
- [ ] CI builds app and Live Activity for an iOS 26 simulator with signing off; `LiveActivity.appex` is embedded.
- [ ] No certificates or provisioning profiles committed.

### M0-12 · CI
- [ ] A PR push and a push to `main` both trigger **Build and test**.
- [ ] `swift test` runs in the same run; a deliberately failing test on a throwaway branch turns the run red (then delete the branch).
- [ ] Screenshots artefact holds the Spike tests screen and Live Activity layouts.
- [ ] Measured minutes per run written in `docs/spikes/m0-12-ci.md`; monthly estimate within ~200 macOS minutes.

### M0-11 · Spike tests screen
- [ ] Reachable from the first screen in one tap (screenshot of first screen).
- [ ] Shows "Set test alarms", the S1b status and "Start test timer" (screenshot `1-spike-tests`).
- [ ] Results are in plain words (screenshots after each tap).
- [ ] Debug-only: gated by `SpikeTests.isEnabled`; a board line exists to hide it before Gate 1.

### M0-04 · S1 Alarms (simulator stand-in)
- [ ] CoachCore `TestAlarmScheduleTests` pass in CI: 14 alarms, first ≥ 2 minutes ahead on a whole minute.
- [ ] In the simulator, "Set test alarms" either registers 14 through AlarmKit and shows "14 alarms set, next at HH:MM", or fails with a plain message. Record which: whether AlarmKit schedules in the iOS 26 simulator is itself a finding for `docs/spikes/s1-alarms.md`.
- [ ] If it registers: the simulator alarm fires at the time shown, with the app in the background (screenshot). Not a substitute for locked, Silent or Focus.
- Deferred: rings locked, on Silent and in a Focus; per-app AlarmKit limit on a real phone.

### M0-05 · S1b Reconcile (simulator stand-in)
- [ ] CoachCore reconcile tests pass in CI, including empty plan and past-only plan never cancelling.
- [ ] On launch the screen shows "Alarm check hasn't run yet" or the reconcile result, never a blank (screenshot).
- [ ] After "Set test alarms", relaunch shows "All alarms set (14)".
- [ ] Planned IDs persist: terminate and relaunch, IDs unchanged (status still all set, nothing re-set).
- Deferred: alarms survive a TestFlight update.

### M0-06 · S3 Live Activity (simulator stand-in)
- [ ] "Start test timer" starts a 90-second countdown on screen (screenshot `3-spike-tests-timer-running`).
- [ ] With the app backgrounded, the Live Activity shows in the Dynamic Island and counts down (screenshot `4-live-activity-dynamic-island`, plus a second shot 10 s later showing a lower number).
- [ ] Lock-screen and Dynamic Island layouts render (screenshot `2-live-activity-layouts`).
- [ ] After 90 s, and after Cancel, no Live Activity remains (screenshot of the Dynamic Island empty).
- Deferred: countdown on the real lock screen while locked; "3, 2, 1, go" through headphones while locked; music ducks and returns.

### M0-08 · S4 GIFs
- [ ] `Content/exercises/exercises.json` decodes and lists 44 exercises, each with a GIF id or named substitute and three callout slots.
- [ ] Licence condition (personal use, bundle not fetch) recorded on the board and in `s4-gifs.md`.

### M0-10 · Gate 0a pack
- [ ] `docs/spikes/gate-0.md` exists: what the simulator proved, what is deferred, screenshots, one recommendation marked.
- [ ] Every deferred item names its on-phone check and the Setup Desk part that covers it.

## Advisor co-sign

The Advisor checks only what touches training: that a 90-second rest default and the voice cue wording are right for the Phase 1 sessions, and that the deferred alarm risk (wake alarms unproven on a device until payment) is acceptable while the CEO trains from paper. Answer each point as accepted, changed or rejected below.

| Advisor point | Answer |
|---|---|
| | |

## Sign-off

| Role | Verdict | Date |
|---|---|---|
| Head of QA and Validation | | |
| Fitness and Nutrition Advisor | | |
