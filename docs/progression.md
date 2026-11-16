# Progression (board M1-08)

`Programme.prescription(for:week:history:)` in CoachCore gives the player each strength item's next target. It replays every logged session in order, so nothing but the set logs is stored. History is shared by exercise across sessions (the lateral raise in Upper A moves the one in Upper B).

**Order.** The plan says reps, then sets, then tempo, then weight. Sets come from the programme's weekly ramp (`sets[]`), so the engine moves the rest, by the item's rule:

| Rule | Every set on target | At the top of the range |
|---|---|---|
| `double` | +1 rep (or up to the lowest set logged) | +1 load step, back to the bottom |
| `reps-tempo-load` | +1 rep | lower over 3 s; then +1 load step, back to the bottom at normal tempo |
| `reps-tempo` | +1 rep | lower over 3 s; then hold |
| `reps` | +1 rep | hold |
| `time` | +5 s | hold |
| `time-then-load` | +5 s | +1 load step, back to the bottom |
| `reps-then-graduate` | +1 rep | with every set of the full week (3) at the top: move to `graduate.to` at the bottom of its range |

**Short sets (design rule 4).** A set below target is *held*: next time is the same as this time, never a step back. Only two short sets in a row of the same exercise in one session *back off*: to the bottom of the range at normal tempo, or one load step lighter if already there. A set with no count that wasn't tapped "as prescribed" (counter unused) is ignored, so it never holds progression back.

**Dumbbell limit (D3).** No prescription goes over `dumbbellLimitKg` (24). `atDumbbellLimit` is true once the next load step would pass it; the player shows "the dumbbells are now the limit".

**Logged weight.** If the owner logs a different dumbbell, that weight becomes the starting point.

**Auto-swap.** `swapPrescription(for:week:history:)` gives the swap exercise's target (push-up → dumbbell bench press), moved by its own history.

**Drop to 2 (R2).** `reducedWeekApplies(history:)` is true when the last two strength sessions' "Still sore from last time?" answers were both Sore. An ignored row counts as Fine. `droppedSessions(history:)` returns `reducedWeek.drop` (full body) for the planner (M2-01) to leave out of the coming week; the next Fine answer ends it.
