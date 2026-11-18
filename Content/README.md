# Content

Data files the app bundles. Phases 2 and 3 are content updates here, not code changes.

| Path | What | Owner |
|---|---|---|
| `programmes/` | `phase-1.json`, `phase-2.json`, `phase-3.json` | Training and Nutrition Researcher |
| `exercises/` | ~40 exercises, each with a GIF and three callouts (setup, movement, common mistake) | Training and Nutrition Researcher |
| `recipes/` | `recipes.json`: box-night entry, breakfasts, home lunches, dinners, Sunday cook, snacks and the ingredient catalogue; every recipe makes two portions, no raw fish, no batch cooking (see `docs/nutrition-content.md`) | Training and Nutrition Researcher |
| `lunch-orders.json` | 6 office orders within ~8 minutes' walk of St James's Market | Training and Nutrition Researcher |
| `routes/hyde-park-loops.json` | 4 named Hyde Park run loops (2–5.9 km) from Victoria Gate; the player names the one closest to the session (N10) | Training and Nutrition Researcher |

The JSON schemas are owned by the Planner Engineer (data model) and versioned; CoachCore validates every file in its tests.
