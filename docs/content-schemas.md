# Content and profile schemas (v1)

Owner: Planner Engineer. Swift models live in `CoachCore/Sources/CoachCore/Content/` and `Profile/`; they are the source of truth, and this page is the summary for people editing content.

## Rules for every format
- Every file and the profile record carry `schemaVersion`. A file from a **newer** build, an **older** unsupported one, or one that won't decode is rejected with a plain message naming the file (and the field, where the JSON is the wrong shape). Nothing is half-loaded.
- **Additive** change (new optional field, or one with a default): keep the version. **Breaking** change (rename, change of meaning): bump the version, update the files, and for the profile add a step to `Profile.migrate`.
- `swift test` (Linux CI on every PR) loads every JSON file in `Content/` and fails on any file it has no schema for, so a new kind of content can't land unchecked.

## `exercises/exercises.json` · `ExerciseCatalogue`
| Field | Notes |
|---|---|
| `schemaVersion` | 1 |
| `mediaSource` | provider, owner, format, licence |
| `exercises[]` | `id` (lower-case-hyphenated, unique), `name`, `group` (push, pull, legs, core, arms, shoulders, warm-up), `equipment[]` (bodyweight, dumbbells, bench, band, pull-up bar), `usedIn` (for editors), `media` or null, `substitute` (whose GIF stands in), `swap` (do instead on pain or kit problem), `callouts` {`setup`, `movement`, `commonMistake`} |

Checked: unique ids, callouts 1–12 words, `substitute` and `swap` exist and aren't self, no media means a substitute that has media.

## `programmes/<id>.json` · `Programme`
File name must equal `id`. Per-week arrays have exactly `weeks` values, week 1 first.

| Field | Notes |
|---|---|
| `schemaVersion` | 1 |
| `id`, `phase`, `name`, `weeks`, `maxSessionMinutes`, `warmUpMinutes` | |
| `loadStepKg` | smallest increment, per dumbbell |
| `dumbbellLimitKg` | **moved in v1** from `progressionRules.dumbbellLimitKg` |
| `effort[]` | `week`, `mainSets`, `repsInReserve`, `cue` |
| `progressionRules` | rule name → plain-English description; every rule used must be described |
| `fixed[]` | events planned around, not run: `id`, `name`, `kind`, `day`, `time`, `note` |
| `placementRules` | `neverOn[]`, `notTheDayBefore` {fixed id → session ids}, `longSlot`, `outdoorSessions[]` |
| `reducedWeek` | `trigger`, `drop[]`, `keep[]` (session ids) |
| `schedule[]` | `week`, `days` {monday…sunday → session id, fixed id, or null}; all seven days present |
| `sessions` | id → session, by `kind`: `strength`, `run-walk`, `circuit`, `walk` |

Strength items: `exercise`, `sets[]`, `repsInReserve[]`, exactly one of `reps` or `seconds` {`min`, `max`}, `perSide`, `startKg` (per dumbbell, null = bodyweight, ≤ `dumbbellLimitKg`), `tempo`, `progression` (double, reps-tempo-load, reps-tempo, reps, time, time-then-load, reps-then-graduate; `time*` need `seconds`), optional `note`, `graduate` (only with reps-then-graduate), `autoSwap`.

Checked as well: schedule weeks 1…`weeks`; every scheduled id exists; nothing but fixed events on `neverOn` days; a scheduled run-walk has a plan for that week; indoor swaps point at a circuit; strength durations within `maxSessionMinutes`; every exercise named (warm-ups, items, graduate, autoSwap, circuit) exists in `exercises.json`.

## Profile record · `Profile`
One record, stored by the app in SwiftData as this JSON (`ProfileRecord.payload`). Any field missing at any depth takes its default, so adding a field never needs a migration.

| Section | Fields (defaults from requirements §12, decision E6) |
|---|---|
| top | `schemaVersion` 1, `confirmed` false (true after "Looks right") |
| `about` | `name`, `heightCm`, `weightKg` (all optional), `painAreas[]` (empty = nothing hurts) |
| `goal` | `target` lean-and-strong, `phaseWeeks` 6 |
| `schedule` | `sleepHours` 7.5, `fallAsleepMinutes` 15, `windDownMinutes` 30, `latestBedtime` 23:30, `earliestWake` 05:45, `workStart` 09:00, `workEnd` 18:00, `trainingWindows` both, `longSessionDay` sunday |
| `training` | `maxSessionMinutes` 45, `dumbbellMaxKg` 24, `hasBench`, `hasPullUpBar`, `voiceCues` true, `counting` tap |
| `coach` | `checkInDay` sunday, `checkInTime` 18:00, `moodCheck` true, `quietFrom` 22:30, `quietUntil` 06:00 |
| `programme` | `programmeID` phase-1, `startDate` (Monday of week 1; set at onboarding) |

Times are `"HH:mm"`, dates ISO 8601. Personal details (postcode, office address) are deliberately not defaults in code; onboarding (M1-04) asks or leaves them empty.

## The app's store (SwiftData)
`SchemaV1` holds `ProfileRecord` (the profile JSON above, as bytes). A model change ships as `SchemaV2` plus a stage in `HealthCoachMigrationPlan`, never as an edit to `SchemaV1`. If the store won't open, the app never crashes: a readable but broken store is moved aside as `HealthCoach-unreadable-<time>.store` (never deleted) and a fresh one opens; an unreadable one (protected before first unlock) is left alone and that launch runs in memory. `AppStore.recovery` says which happened, for a one-line notice on Today.
