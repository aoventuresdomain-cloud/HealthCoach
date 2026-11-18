# Nutrition content (M3-01)

Owner: Training and Nutrition Researcher · Advisor reviews · 17 Nov 2026

Two files, both provisional schema version 0 (the Planner Engineer owns the schema and may rename fields when M3-02 and M3-03 load them):

- `Content/recipes/recipes.json`: the box-night entry, 4 breakfasts, 3 home lunches, 10 home dinners for nights the box doesn't cover, 3 Sunday cooks and 2 snacks. Every recipe makes exactly 2 portions and has its minutes and per-portion calories and protein. Ingredients sit in one catalogue (name, aisle, staple flag, per-100 g values and a Waitrose search term), so the top-up list can merge quantities, sort by `aisleOrder` and build one search link per item from `shop.searchUrl` (decision E5).
- `Content/lunch-orders.json`: 6 office-day orders at 4 places within about 8 minutes' walk of St James's Market, each with calories, protein, an approximate price and where the nutrition came from.

## How a Phase 1 day adds up

| Moment | Typical | kcal | Protein |
|---|---|---|---|
| Breakfast | any of the 4 | 480–530 | 39–47 g |
| Lunch | home recipe or office order | 470–710 | 45–63 g |
| Dinner | box night (fixed entry), home dinner or Sunday cook | 560–720 | 38–69 g |
| Snack | yogurt pot; shake instead if the planned day is under 150 g protein | 220–260 | 21–34 g |
| **Day** | | **~1,710–2,210 combined** | **~145–200 g** |

Targets are in `dailyTargets` (2,000 kcal, 160 g protein, about 40 g at each of 4 eating moments, 2 untracked social meals a week), from plan §2 and §4.3. The rules engine moves the calorie target week to week, so M3-02 plans only days within ±150 kcal of the current target (`kcalBandPlusMinus`), never below 1,700 kcal (`kcalFloor`), with at least 150 g protein (`proteinMin`). `snackRule`: the yogurt pot by default, the shake when the planned day is under 150 g, and at 17:30 on Wednesdays before basketball. `supplements`: one pre-ticked line with breakfast (creatine 5 g daily; vitamin D 10 µg from October to March, as the NHS advises).

## Rules held in the data

- 2 portions exactly (the shake is 1, the owner's only), no batch cooking: overnight oats are made the night before for the next morning only.
- No raw fish: fish is tinned tuna, cooked prawns heated through, or salmon, trout, mackerel and cod cooked until opaque. The itsu order says to skip sushi and poke.
- Box nights add nothing to the top-up list; they're recorded at 650 kcal and 40 g protein a portion.
- Values are estimates from typical UK label figures (recipes) or the chain's published nutrition (lunch orders; Farmer J is an estimate at 700 kcal, as no figures were published). Tracking is loose by design: nobody weighs food.

## Dinner variety (N6, Advisor A4)

No dinner repeats within any 3 weeks. Home dinners are taken in file order, a whole week's worth at a time (MealPlan), so 10 dinners cover 3 weeks at 2 home nights (4 box nights, the default) or 3 (3 box nights). The 3 Sunday cooks rotate weekly. The order is deliberate: dinners sit in pairs of an oily fish then something else, so every week has an oily fish at home (salmon, trout or mackerel).

| Pair | Oily fish | Other |
|---|---|---|
| 1 | Baked salmon, new potatoes and greens | Chicken noodle stir-fry |
| 2 | Sticky soy-glazed salmon and rice | Turkey and bean chilli |
| 3 | Pesto trout, crushed potatoes and beans | Garlic prawn linguine |
| 4 | Grilled mackerel with warm lentils | Chicken fajitas |
| 5 | Salmon tikka with spinach and rice | Cod with smoky butter beans |

Sunday cooks: pork tenderloin with apples and roots, the chicken traybake, and a cod and prawn fish pie.

Advisor A4 rules, checked for every dinner and Sunday cook (the CoachCore test checks the numeric ones):
- 550–750 kcal a portion and at least 35 g protein (aim 40 g).
- At least 2 portions of veg (160 g or more) a portion.
- 12 ingredients or fewer; weeknight dinners 40 minutes or less in total.
- Cooked fish twice a week, one oily: the home oily fish plus one fish recipe picked from the box (the box note says so). The fish pie and the cod and prawn dinners add more in some weeks.
- At most 2 red-meat dinners a week: the only home red meat is the pork Sunday cook, and the box note asks for at most one red-meat box recipe.
- Ingredients repeat across the set (salmon, rice pouches, spinach, peas, cherry tomatoes, peppers, yogurt, lemons), so half-packs get used up. Everything is a Waitrose line (E5).
- `mainIngredients` tags each dinner and Sunday cook (for example `salmon`, `oily-fish`) for a dislike list in Preferences. The list is empty by default.

## Refresh

The lunch list needs re-checking monthly (requirements §4.5): places close and menus change. Nothing in it needs a paid API.

## Extras (`recipes[]` with `"kind": "extra"` in `Content/recipes/recipes.json`)

The base recipes reach about 1,710–2,210 kcal a day. When the rules engine raises the target (up to 2,200 in the cut, about 2,450 at maintenance), the planner first adds a chicken boost (150 kcal, 31 g) whenever planned protein is under 150 g. It then adds extras in this order until the day is inside the band: one side (rice, potatoes or bread, 160–200 kcal; on training days with the first meal after the session), the yogurt-granola bowl (320 kcal, 25 g), the richer breakfast (+~180 kcal over the base), and cheese on toast last (390 kcal, 19 g; lowest protein per kcal). Carbs and protein come before fat. Each is used at most once a day, and the planner adds at most 2 extras a day (Head of Engineering), which covers targets up to maintenance (~2,450; tested). Cooked extras make 2 portions; snacks for the owner alone make 1. No batch cooking, no raw fish.
