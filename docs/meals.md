# Meals and the top-up list (board M3-02, M3-03)

**Where.** `MealPlan`, `ShoppingList` and the content types are in CoachCore under `Nutrition/` and tested on Linux (`NutritionTests`). Content: `Content/recipes/recipes.json` and `Content/lunch-orders.json` (schema in `docs/content-schemas.md`, editor notes in `docs/nutrition-content.md`).

**The week (`MealPlan.week`).** No questions. Planned meals are pre-ticked and count unless the owner changes them.
- **Dinner** is set by the day (E15): box nights Mon–Thu at 650 kcal and 40 g a portion; home dinners on Fri and Sat, rotating; the Sunday cook on Sunday.
- **Lunch:** an office order on office days (from the Sunday prompt's answers), otherwise a home lunch. Both rotate, so the week doesn't repeat an order.
- **Breakfast** rotates through the four breakfasts, offset by week so consecutive weeks differ.
- **Snack:** the yogurt pot, or the shake when the day would otherwise be under 150 g protein (Advisor rule). On Wednesdays it's at 17:30, before basketball.
- **Supplements:** one pre-ticked line with breakfast, by month (creatine all year; vitamin D October to March).

**The band (Advisor rule, gate 1–2).** Every day is within the week's target ± 150 kcal, never under 1,700, with at least 150 g protein. The target is `dailyTargets.kcal` (2,000 in Phase 1) unless the rules engine passes this week's (`kcalTarget:`). For each day the planner takes the first breakfast and lunch pair in rotation that lands within ± 75 kcal of the target. Failing that, it takes the first pair inside the band, and failing that, the closest pair (`withinBand` is then false). Same week in, same plan out.

**Reach of the current recipes.** At the Phase 1 content, a home-lunch day spans about 1,710–2,030 kcal, and a box-night day about 1,820–1,990. A target from 1,850 up to about 2,000 fills every day, as the tests check. A higher weekly target (the engine raising calories, maintenance at ~2,450) is closed with **extras**: `recipes[]` entries with `"kind": "extra"`, filled by `extraRules` (Advisor order, 17 Nov). When planned protein is under 150 g, the chicken boost goes in first. Then come one side (rice, potatoes or bread, rotating by day), the yogurt bowl, the richer breakfast (which replaces the planned breakfast) and cheese on toast last, until the day is in the band. That is at most 2 extras a day (Head of Engineering), one of each kind, and never one that overshoots. Extras are pre-ticked and their ingredients go on the top-up list. Tests check every day in the band at 2,200 and 2,450 for home, office and hybrid weeks. Without a fitting extra, a day is planned as close as it gets and flagged `withinBand = false`; nothing is invented.

**Top-up list (`ShoppingList.week`).** One list for the week. Quantities are merged across every recipe use and sorted by `aisleOrder`, then by name. Box nights and office lunches add nothing, and supplements are staples. A staple the owner has ticked stays ticked (the app stores `tickedStaples`); everything else starts unticked each week. Each line has a search link to the default shop (`shop.searchUrl`, E5).

**Cut for this round (re-plan, 17 Nov):** the evening "anything different?" prompt and the social-meal counter.

**C3: meals follow the target (Advisor, 18 Nov).** Pass `trainingDays` (from `WeekPlan.trainingDays(programme:)`: strength, run and basketball days; a walk doesn't count). There is no formal split, but within the band training days aim up to +75 kcal and rest days down to −100, balanced so the week's aims average the target (`MealDay.aimKcal`). Extras fill towards each day's aim. Then `balance` moves the week's average to within ±40 kcal of the target: it adds an extra to a training day first, takes one off a rest day first, and moves an extra from a rest day to a training day if rest days come out heavier. Every day stays within ±150 kcal of the target, at or above 1,700 kcal, and at or above 150 g protein. Box nights stay Mon–Thu. The top-up list follows the meals, so it changes with the target. Without `trainingDays`, the plan is the M3-02 one.

**C4: social meals (Advisor, 18 Nov).** `MealPlan.withSocialMeals(dates)` handles a social meal as follows:
- The meal counts as 1,000 kcal untracked and replaces that day's dinner. The day is exempt from the band, and its other meals stay as planned.
- The excess (1,000 kcal minus the replaced dinner) comes off the week's other days as a "Lighter carbs" line. Days after the social meal go first. Each day loses at most 100 kcal, protein is never touched, and no day goes under 1,700.
- What doesn't fit is absorbed. Nothing carries into next week.

`SocialMeals.count` gives "1 of 2". A third is allowed, and `CoachSummary.text(socialMeals:)` flags it.
