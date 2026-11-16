# S4 · Exercise GIFs (M0-08)

**Result: pass, with one licence condition.** All 44 exercises the Phase 1–3 programmes will draw on are listed in `Content/exercises/exercises.json`. 42 have an ExerciseDB V1 GIF; 2 have a named substitute. The GIFs are fine for this single-user app; they are not cleared for any wider release.

Owner: Training and Nutrition Researcher · 2026-11-16

## Licence (ExerciseDB V1)

| Question | Finding | Source |
|---|---|---|
| What is V1? | AscendAPI's free tier ("previously ExerciseDB"): about 1,500 exercises, one 180×180 GIF each, no key or sign-up. API `oss.exercisedb.dev/api/v1/exercises`; media at `static.exercisedb.dev/media/<id>.gif` | exercisedb.dev; docs.ascendapi.com/products/edb-v1/overview |
| Is there a licence for the GIFs? | **None published that we could find.** The GitHub repo `ExerciseDB/exercisedb-api` carries an AGPL-3.0 `LICENSE`, but holds only a README (3 commits, checked by clone), so the AGPL covers no code and says nothing about media. The terms-of-use link and V1 docs did not load from our environment | github.com/ExerciseDB/exercisedb-api |
| Who owns the media? | AscendAPI / ExerciseDB. Public re-hosts of the same files (Kaggle, `Alejor-Dev/ejercicios-dataset`) label them "educational, non-commercial use only" and say commercial use needs the owner's permission | github.com/Alejor-Dev/ejercicios-dataset |
| Stability | AscendAPI's own README calls its free endpoints "for exploration only and not recommended for production integration", with strict rate limits | ExerciseDB README |
| Cost | £0. No key, no account, no paid tier needed for 180p | — |

**What this means for us**

- Personal, non-commercial use in an app installed only on the CEO's phone through internal TestFlight is the use the free tier is offered for. Accepted risk: low.
- **Bundle the 42 GIFs into the app** (a one-off download into the app bundle in M1), never fetch them at runtime. The free endpoint is unstable and the app must work offline.
- **Before any wider release** (App Store, external TestFlight testers, sharing the app): get written permission from AscendAPI, buy the paid licence, or switch to the fallback below. This matches plan §9.
- 180×180 is soft at full screen width. Show the GIF at about 180–240 pt; the callouts carry the detail.

**Fallback:** `yuhonas/free-exercise-db`, released under the Unlicense (public domain, commercial use allowed). Two still JPGs per exercise rather than a GIF, so the player would cross-fade the two frames. Use it only if the licence position changes.

## Exercise list

44 exercises: 13 push (with shoulders and triceps), 11 pull (with biceps), 10 legs (light, full-body day only), 8 core and carry, 2 warm-up. Runs are voice-guided and need no GIF. Media IDs are ExerciseDB V1 IDs; the URL is `https://static.exercisedb.dev/media/<id>.gif`.

| Exercise | Group | Used in | GIF (V1 id, provider name) | Angle |
|---|---|---|---|---|
| Dumbbell bench press | push | Upper A, all phases | `SpYC0Kp` (dumbbell bench press) | front |
| Dumbbell incline bench press | push | Upper B, all phases | `ns0SIbU` (dumbbell incline bench press) | front |
| Push-up | push | Warm-up set, finisher, travel | `I4hDWkc` (push-up) | side |
| Feet-on-bench push-up | push | Phase 2–3 finisher | `i5cEhka` (decline push-up) | side |
| Dumbbell fly | push | Upper A, Phase 2–3 | `yz9nUhF` (dumbbell fly) | front |
| Seated dumbbell shoulder press | push | Upper B, all phases | `znQUdHY` (dumbbell seated shoulder press) | front |
| Arnold press | push | Upper B, Phase 3 variation | `Xy4jlWA` (dumbbell arnold press) | front |
| Lateral raise | shoulders | Upper A and B, all phases | `DsgkuIt` (dumbbell lateral raise) | front |
| Bent-over reverse fly | shoulders | Upper A and B, all phases | `EAs3xL9` (dumbbell reverse fly) | front |
| Standing external rotation | shoulders | Warm-up, all phases | `x306lCW` (dumbbell upright shoulder external rotation) | front |
| Lying triceps extension | arms | Upper A, all phases | `mpKZGWz` (dumbbell lying triceps extension) | side |
| Seated overhead triceps extension | arms | Upper B, all phases | `kont8Ut` (dumbbell seated triceps extension) | front |
| Bench dip | arms | Finisher, Phase 2–3 | `RrLske5` (bench dip (knees bent)) | side |
| Pull-up | pull | Upper A and B, once able | `lBDjFxJ` (pull-up) | rear-three-quarter |
| Chin-up | pull | Upper A and B, all phases | `T2mxWqc` (chin-up) | rear-three-quarter |
| Negative pull-up (slow lower) | pull | Upper A and B, Phase 1 regression | none | substitute: pull-up |
| Band-assisted pull-up | pull | Fallback if no bar or for extra reps | `r1XNRYB` (band assisted pull-up) | rear-three-quarter |
| Scapular pull-up | pull | Warm-up, all phases | `uTBt1HV` (scapular pull-up) | rear-three-quarter |
| One-arm dumbbell row | pull | Upper A, all phases | `C0MA9bC` (dumbbell one arm bent-over row) | front |
| Chest-supported incline row | pull | Upper B, all phases | `7vG5o25` (dumbbell incline row) | side |
| Dumbbell pullover | pull | Upper B, Phase 2–3 | `9XjtHvS` (dumbbell pullover) | side |
| Dumbbell curl | arms | Upper A, all phases | `NbVPDMW` (dumbbell biceps curl) | front |
| Hammer curl | arms | Upper B, all phases | `slDvUAU` (dumbbell hammer curl) | front |
| Incline curl | arms | Upper A, Phase 2–3 | `ae9UoXQ` (dumbbell incline curl) | front |
| Goblet squat | legs | Full body, all phases | `yn8yg1r` (dumbbell goblet squat) | front |
| Split squat | legs | Full body, Phase 1 | `9E25EOx` (split squats) | front |
| Bulgarian split squat | legs | Full body, Phase 2–3 | `qx4fgX7` (dumbbell single leg split squat) | front |
| Romanian deadlift | legs | Full body, all phases | `rR0LJzx` (dumbbell romanian deadlift) | front |
| Reverse lunge | legs | Full body, swap for split squat | `SSsBDwB` (dumbbell rear lunge) | side |
| Step-up | legs | Full body, Phase 2–3 | `aXtJhlg` (dumbbell step-up) | side |
| Glute bridge | legs | Warm-up, Phase 1 | `u0cNiij` (low glute bridge on floor) | side |
| Feet-on-bench glute bridge | legs | Full body, Phase 2–3 | `aWedzZX` (glute bridge two legs on bench (male)) | side |
| Standing calf raise | legs | Full body, all phases | `dPmaUaU` (dumbbell standing calf raise) | side |
| Single-leg calf raise | legs | Full body, Phase 2–3 | `1kB3Wmk` (dumbbell single leg calf raise) | side |
| Front plank | core | Core block, all phases | `VBAWRPG` (weighted front plank) | side |
| Side plank | core | Core block, all phases | `RKjH6Lt` (side bridge v. 2) | side |
| Dead bug | core | Core block, Phase 1 | `iny3m5y` (dead bug) | side |
| Hollow hold | core | Core block, Phase 3 | none | substitute: dead-bug |
| Reverse crunch | core | Core block, Phase 1–2 | `nCU1Ekp` (reverse crunch) | side |
| Hanging knee raise | core | Core block, Phase 2–3 | `I3tsCnC` (hanging leg raise) | front |
| Hanging leg raise | core | Core block, Phase 3 | `4Ml7QFO` (hanging straight leg raise) | front |
| Farmer's carry | core | Full body finisher, all phases | `qPEzJjA` (farmers walk) | front |
| World's greatest stretch | warm-up | Warm-up, every session | `DFGXwZr` (world greatest stretch) | side |
| Scapular push-up | warm-up | Warm-up, upper days | `jV65tKx` (scapula push-up) | side |

**Exercises without their own GIF**

| Exercise | Substitute GIF | Why it works |
|---|---|---|
| Negative pull-up | Pull-up (`lBDjFxJ`) | Same path; the callout says "jump or step to the top, lower for 3–5 s" |
| Hollow hold | Dead bug (`iny3m5y`) | Same position at the start; the callout says "hold, arms and legs still" |

**Angle notes**

- Every GIF was checked frame by frame (a contact sheet of mid-frames, not committed because the media isn't ours to redistribute).
- 4 bar exercises (pull-up, chin-up, band-assisted pull-up, scapular pull-up) are shown from a rear three-quarter angle that turns side-on mid-rep. ExerciseDB has no front view of these; the back view is the useful one because it shows the shoulder blades. Engineering to accept or reject against the Done when line.
- Renamed to match the GIF: `glute-bridge-feet-on-bench` (the GIF shows feet on the bench, not a shoulders-on-bench hip thrust). ExerciseDB's "hanging leg raise" is a knee raise, so it is used for `hanging-knee-raise`; the straight-leg version uses "hanging straight leg raise".

## How verified

- Exercise names, IDs and GIF files come from a public mirror of the V1 media whose files are named `<index>-<V1 id>.gif` and stated byte-identical to the CDN copies. Our environment blocks `exercisedb.dev`, so the CDN URLs were not fetched directly. The first M1 download step must confirm each URL returns a GIF and fail loudly if not.
- No paid service, API key or account was used.

## Open points

1. The terms-of-use page could not be read from here. If anyone can open `https://dub.sh/exercisedb-api-tos` from a normal browser, add a one-line summary above. Not blocking for single-user use.
2. Callout text (setup, movement, common mistake) is written in M1, after the Phase 1 programme is drafted and checked with the Advisor.
