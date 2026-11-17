# Nutrition content (M3-01)

Owner: Training and Nutrition Researcher · Advisor reviews · 17 Nov 2026

Two files, both provisional schema version 0 (the Planner Engineer owns the schema and may rename fields when M3-02 and M3-03 load them):

- `Content/recipes/recipes.json`: the box-night entry, 4 breakfasts, 3 home lunches, 2 weeknight dinners for nights the box doesn't cover, 1 Sunday cook and 2 snacks. Every recipe makes exactly 2 portions and has its minutes and per-portion calories and protein. Ingredients sit in one catalogue (name, aisle, staple flag, per-100 g values and a Waitrose search term), so the top-up list can merge quantities, sort by `aisleOrder` and build one search link per item from `shop.searchUrl` (decision E5).
- `Content/lunch-orders.json`: 6 office-day orders at 4 places within about 8 minutes' walk of St James's Market, each with calories, protein, an approximate price and where the nutrition came from.

## How a Phase 1 day adds up

| Moment | Typical | kcal | Protein |
|---|---|---|---|
| Breakfast | any of the 4 | 480–530 | 39–47 g |
| Lunch | home recipe or office order | 470–710 | 45–63 g |
| Dinner | box night (fixed entry) or home dinner | 540–710 | 40–56 g |
| Snack | yogurt pot; shake instead if the planned day is under 150 g protein | 220–260 | 21–34 g |
| **Day** | | **~1,710–2,210 combined** | **~145–200 g** |

Targets are in `dailyTargets` (2,000 kcal, 160 g protein, about 40 g at each of 4 eating moments, 2 untracked social meals a week), from plan §2 and §4.3. M3-02 plans only days inside 1,850–2,150 kcal with at least 150 g protein (`kcalMin`, `kcalMax`, `proteinMin`). `snackRule`: the yogurt pot by default, the shake when the planned day is under 150 g, and at 17:30 on Wednesdays before basketball. `supplements`: one pre-ticked line with breakfast (creatine 5 g daily; vitamin D 10 µg from October to March, as the NHS advises).

## Rules held in the data

- 2 portions exactly (the shake is 1, the owner's only), no batch cooking: overnight oats are made the night before for the next morning only.
- No raw fish: fish is tinned tuna, cooked prawns heated through, or salmon baked until opaque. The itsu order says to skip sushi and poke.
- Box nights add nothing to the top-up list; they're recorded at 650 kcal and 40 g protein a portion.
- Values are estimates from typical UK label figures (recipes) or the chain's published nutrition (lunch orders; Farmer J is an estimate at 700 kcal, as no figures were published). Tracking is loose by design: nobody weighs food.

## Refresh

The lunch list needs re-checking monthly (requirements §4.5): places close and menus change. Nothing in it needs a paid API.
