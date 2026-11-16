# HealthCoach

A personal iPhone fitness and nutrition coach. Native SwiftUI (iOS 26+), built by Xcode Cloud and installed through TestFlight.

**Guiding rule:** if it takes thinking or admin time, it has failed.

- Plan (wins over every other file): [docs/fitness-coach-project-plan.md](docs/fitness-coach-project-plan.md)
- Work board: [docs/board.md](docs/board.md)
- Decisions: [docs/decisions.md](docs/decisions.md)

## Layout

```
HealthCoach.xcodeproj  app + LiveActivity targets, shared scheme "HealthCoach"
App/            SwiftUI app target (folder-synced: new files join the target)
LiveActivity/   widget extension: lock-screen and Dynamic Island timer
Shared/         compiled into both App and LiveActivity (ActivityKit types)
CoachCore/      Swift package, Foundation only, no iOS dependencies
  Sources/CoachCore/Planner/   week placement, wake times, alarm schedule
  Sources/CoachCore/Rules/     calories from trend, progression, recovery, stall flag
  Sources/CoachCore/Import/    versioned Claude block parser and validator
  Tests/CoachCoreTests/        swift test (Xcode Cloud, any Mac, Linux)
Content/        programmes, exercises, recipes, lunch orders (data, not code)
ci_scripts/     Xcode Cloud hooks
docs/           plan, board, decisions, spikes/, handoffs/
```

CoachCore uses the standard SwiftPM `Sources/` and `Tests/` layout rather than the plan's §13 sketch of `CoachCore/Tests/` beside the module folders; the content is the same.

## Run the core tests

```
cd CoachCore && swift test
```

In Xcode, the `HealthCoach` scheme's Test action (⌘U) runs `CoachCoreTests` too.

## Rules for every change

- One owner per item, assigned on the board by the Head of Engineering, who is the only one who merges.
- Every item has 2–5 checkable "Done when" lines; review and QA test against them.
- No secrets in the repo. No health data or photos leave the phone except the owner's iCloud backup and the summaries they choose to share with Claude.
- No paid services or APIs without the owner's go-ahead.
