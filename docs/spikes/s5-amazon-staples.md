# S5 · Amazon basket spike: staples mapping (N11, Researcher part)

Status 18 Nov: **list ready, ASINs not mapped.** This environment cannot reach amazon.co.uk (the network proxy refuses the host), and search engines do not return reliable ASINs. A fabricated or guessed product ID would put the wrong item in the basket, so none are filled in.

**What's needed to finish:** on a machine that can open amazon.co.uk, search each term below, pick the closest pack (own-brand or the named product), and copy the 10-character ASIN from the product URL (`/dp/XXXXXXXXXX`). That takes about 20 minutes for 38 lines. The Planner's link test (does a multi-item cart link fill the basket, and does fresh delivery reach W2) decides whether it's worth doing. If the spike is cut, nothing here ships.

Recurring items are every ingredient used by a breakfast, lunch or snack, plus supplements and whey: 38 lines. Dinners vary by week, so they stay on the Waitrose list.

| Ingredient id | Name | Aisle | Staple | Search term | Delivery | Amazon ASIN |
|---|---|---|---|---|---|---|
| `apple` | Apples | produce | no | apples | ambient | _to map_ |
| `banana` | Bananas | produce | no | bananas | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `cherry-tomatoes` | Cherry tomatoes | produce | no | cherry tomatoes | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `cucumber` | Cucumber | produce | no | cucumber | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `lemon` | Lemons | produce | no | lemons | ambient | _to map_ |
| `red-onion` | Red onions | produce | no | red onions | ambient | _to map_ |
| `rocket` | Rocket | produce | no | wild rocket | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `salad-leaves` | Mixed salad leaves | produce | no | mixed salad leaves | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `spinach` | Baby spinach | produce | no | baby spinach | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `spring-onions` | Spring onions | produce | no | spring onions | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `pitta` | Wholemeal pitta | bakery | no | wholemeal pitta | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `tortilla` | Wholemeal tortilla wraps | bakery | no | wholemeal tortilla wraps | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `wholemeal-bread` | Wholemeal sourdough loaf | bakery | no | wholemeal sourdough | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `cooked-chicken` | Cooked chicken breast pieces | meat-and-fish | no | cooked chicken breast pieces | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `cooked-prawns` | Cooked king prawns | meat-and-fish | no | cooked king prawns | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `butter` | Butter | dairy-and-eggs | yes | salted butter | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `egg-whites` | Liquid egg whites | dairy-and-eggs | no | liquid egg whites | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `eggs` | Free-range eggs, large | dairy-and-eggs | no | free range large eggs 12 | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `feta` | Feta | dairy-and-eggs | no | greek feta | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `greek-yogurt-0` | 0% fat Greek yogurt | dairy-and-eggs | no | 0% fat greek yogurt 1kg | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `light-cheddar` | Reduced-fat mature cheddar | dairy-and-eggs | no | reduced fat mature cheddar | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `milk` | Semi-skimmed milk | dairy-and-eggs | no | semi skimmed milk 2 pints | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `hummus` | Reduced-fat houmous | chilled | no | reduced fat houmous | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `frozen-berries` | Frozen mixed berries | frozen | no | frozen mixed berries | chilled/fresh: only if Amazon fresh reaches W2 | _to map_ |
| `peas` | Frozen peas | frozen | yes | frozen garden peas | ambient | _to map_ |
| `cannellini` | Cannellini beans (tin) | tins-and-jars | yes | cannellini beans | ambient | _to map_ |
| `tuna` | Tuna steak in spring water (tin) | tins-and-jars | yes | tuna in spring water | ambient | _to map_ |
| `rice-pouch` | Microwave basmati rice pouch | rice-pasta-grains | yes | microwave basmati rice | ambient | _to map_ |
| `granola` | Low-sugar granola | cereals | yes | low sugar granola | ambient | _to map_ |
| `oats` | Porridge oats | cereals | yes | porridge oats | ambient | _to map_ |
| `honey` | Honey | oils-sauces-and-spices | yes | runny honey | ambient | _to map_ |
| `olive-oil` | Extra virgin olive oil | oils-sauces-and-spices | yes | extra virgin olive oil | ambient | _to map_ |
| `sesame-oil` | Toasted sesame oil | oils-sauces-and-spices | yes | toasted sesame oil | ambient | _to map_ |
| `soy-sauce` | Reduced-salt soy sauce | oils-sauces-and-spices | yes | reduced salt soy sauce | ambient | _to map_ |
| `almonds` | Flaked almonds | nuts-and-snacks | yes | flaked almonds | ambient | _to map_ |
| `creatine` | Creatine monohydrate powder | sports-nutrition | yes | creatine monohydrate | ambient | _to map_ |
| `vitamin-d` | Vitamin D 10 µg tablets | sports-nutrition | yes | vitamin d 10ug | ambient | _to map_ |
| `whey` | Whey protein, vanilla | sports-nutrition | yes | whey protein powder | ambient | _to map_ |

Privacy: the link carries only product IDs and quantities (no names, calories or health data), per the gap plan §4.7.
