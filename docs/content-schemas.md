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

## `recipes/recipes.json` · `NutritionContent`

Schema owner: Planner Engineer. Content owner: the Researcher (Advisor reviews). Notes for editors are in `docs/nutrition-content.md`.

| Field | Meaning |
|---|---|
| `shop` | `default` shop and `searchUrl` with `{search}` (decision E5) |
| `aisleOrder` | aisle ids in walking order; every ingredient's `aisle` must be one of them |
| `dailyTargets.<programme>` | `kcal` (starting target), `kcalBandPlusMinus` (≤ 150), `kcalFloor` (≥ 1,700), `protein`, `proteinMin` (≥ 150) |
| `snackRule` | `default` snack, `replaceWith` when the day is under `whenPlannedProteinBelow`, and the Wednesday `wednesdayTime` |
| `supplements.items[]` | `ingredient`, `label`, `qty`, `unit`, optional `dose`, `months` (1–12) |
| `boxNight` | the fixed entry: `perPortion`, `nightsPerWeek`, `defaultNights` (E15: Mon–Thu), `shopping: false` |
| `extraRules` | `proteinFirst` (`extra`, `whenPlannedProteinBelow`), `order` ("a\|b" = one of), `maxPerDay` (2), `maxPerKind` (1), `sideTiming` |
| `ingredients.<id>` | `name`, `aisle`, `staple`, `per100`, `unit` (`g`, `ml`, `each`), `gramsEach`, `search` |
| `recipes[]` | `id`, `name`, `kind` (`breakfast`, `lunch`, `dinner`, `sunday-cook`, `snack`, `extra`), `portions` (2; the shake 1; an extra 1 or 2); extras also carry `extraKind`, `addsTo` and optional `replaces`, dinners and Sunday cooks carry `mainIngredients` (main ingredients plus a group such as `oily-fish`, `white-fish`, `shellfish`, `poultry`, `red-meat`, for the dislike filter), `minutes`, `perPortion`, `ingredients[]` (`qty` is the total for all portions), `method[]` |

Validation (`problems()`): known ingredients and aisles, 2 portions, a method, no raw fish words, snack rule names snacks, supplement months 1–12, every meal kind present, box nights within `nightsPerWeek` and never Sunday, and the targets no looser than the Advisor's rule.

## `lunch-orders.json` · `LunchOrders`

`origin` (`maxWalkMinutes`) and `orders[]`: `id`, `place`, `address`, `walkMinutes`, `order`, `kcal`, `protein`, `priceGBP`, `nutritionSource` ("estimate" when none was published), `goodFor`, `note`. Validation: unique ids, within the walk, kcal and protein present, no raw fish.

## `routes/<route>.json` · `RunLoops`

Board N10. Content owner: the Researcher. `route` (the programme's run `route` id), `start` (`name`, `latitude`, `longitude`: a public park gate, never the owner's home) and `loops[]`: `id`, `name`, `distanceKm` (map estimate), `distanceIsEstimate` (true while the distance is a map estimate rather than a measured run), `directions[]`. `closest(toKm:)` gives the loop nearest a session's planned distance. Validation: at least one loop, unique ids, 0.5–15 km, directions present, and one file per route; a CoachCore test checks every programme run route has loops.

## Profile record · `Profile`
One record, stored by the app in SwiftData as this JSON (`ProfileRecord.payload`). Any field missing at any depth takes its default, so adding a field never needs a migration.

| Section | Fields (defaults from requirements §12, decision E6) |
|---|---|
| top | `schemaVersion` 1, `confirmed` false (true after "Looks right") |
| `about` | `name`, `heightCm`, `weightKg` (all optional), `painAreas[]` (empty = nothing hurts) |
| `goal` | `target` lean-and-strong, `phaseWeeks` 6 |
| `schedule` | `sleepHours` 7.5, `fallAsleepMinutes` 15, `windDownMinutes` 30, `latestBedtime` 23:30, `earliestWake` 05:45, `workStart` 09:00, `workEnd` 18:00, `trainingWindows` both, `longSessionDay` sunday, `commuteMinutes` 25, `showerMinutes` 15, `wakeBufferMinutes` 15, `eveningEndBy` 20:30, `dayOffSessionStart` 09:00 |
| `training` | `maxSessionMinutes` 45, `dumbbellMaxKg` 24, `hasBench`, `hasPullUpBar`, `voiceCues` true, `counting` tap |
| `coach` | `checkInDay` sunday, `checkInTime` 18:00, `moodCheck` true, `quietFrom` 22:30, `quietUntil` 06:00 |
| `programme` | `programmeID` phase-1, `startDate` (Monday of week 1; set at onboarding) |

Times are `"HH:mm"`, dates ISO 8601. Personal details (postcode, office address) are deliberately not defaults in code; onboarding (M1-04) asks or leaves them empty.

## The app's store (SwiftData)
`SchemaV1` holds `ProfileRecord` (the profile JSON above, as bytes). A model change ships as `SchemaV2` plus a stage in `HealthCoachMigrationPlan`, never as an edit to `SchemaV1`. If the store won't open, the app never crashes: a readable but broken store is moved aside as `HealthCoach-unreadable-<time>.store` (never deleted) and a fresh one opens; an unreadable one (protected before first unlock) is left alone and that launch runs in memory. `AppStore.recovery` says which happened, for a one-line notice on Today.
