# Gap analysis, market check and build plan (18 Nov 2026)

Written after the CEO's review on 18 Nov at 07:45. The CEO said the app falls well short of what he described, and named six things: check-ins, improvement (the plan adapting), the grocery list, the survey, easy design and photo analysis. Kept by the requirements thread; Head of Engineering owns the build that follows.

## 1. The honest answer first

**The CEO is right. The Gate 2 pack and the feature list overclaimed.** The feature list said "everything below is built", and each line was true for the engine underneath, but a lot of it is invisible or thin from the user's side:

- **There is no weekly check-in at all.** The rules engine recalculates silently. Onboarding even asks for a check-in day and time, and nothing uses that setting.
- **The plan adapts, but you never see it.** Calories move on the weight trend and loads progress, but no screen says what changed or why.
- **The app runs out at week 6.** Only `phase-1.json` exists. Phases 2 and 3 (weeks 7–20) are not written yet (board C5, in progress).
- **Nothing can be changed after onboarding.** There is no Settings or Preferences screen, so the "survey" is a one-off confirm screen.
- **Photos are a list of thumbnails.** No comparison, no outline to line up against, no analysis.
- **The grocery list is the core only.** No choice of shop (Waitrose is hard-coded), no in-store mode, no delivery reminder, no way to share it, and 19 recipes for a 20-week plan.

What is genuinely solid: the planner, wake alarms (simulator), the workout and run-walk players, progression within Phase 1, the meal plan following the calorie target, the Claude summary and import, and the Advisor's safety limits. That is the engine. What is missing is mostly the layer the CEO actually touches.

**Assumptions** (no questions to the CEO, per the standing order):
- "Check-ins" = a short weekly ritual, as in the original draft (§4.6, "under 5 minutes"), not daily logging.
- "Improvement" = the plan visibly adapting week to week and across phases.
- "Survey" = the onboarding questionnaire plus being able to change any answer later, not a feedback survey.
- "Photo analysis" = comparing photos meaningfully over time, done on the phone. Not an AI body-fat score from a cloud service (see §4.6).
- "Easy design" = fewer taps and less to read for each daily job, measured, not a new look.

## 2. Gap list: every promised capability

Sources: the plan (`fitness-coach-project-plan.md`, wins), the owner draft (`00-requirements-v1-owner-draft.md`, onboarding tables §12 still hold), the feature list of 17 Nov, and the code on `main` at `2da4506`.

**Built** = works end to end in the simulator. **Partial** = engine or part of it exists, user-facing part thin or missing. **Missing** = not built. **Cut** = cut on 17 Nov for the deadline. **Deferred** = built, needs the paid account and phone to prove.

### Check-ins
| Capability | Status | Evidence |
|---|---|---|
| Sunday prompt (office days, early/late), under 20 s | Built | `SundayPromptView.swift`, UI test |
| Weekly check-in, under 5 min: trend, photos, strength, how you felt (draft §4.6) | **Missing** | No screen. `coach.checkInDay` is set in onboarding and read nowhere |
| Check-in re-asks what may have changed (weight, office pattern, kit) (draft §12) | **Missing** | |
| "Still sore?" recovery check before a session | Built | Today; two "Sore" answers drop to 2 sessions |
| Daily mood check | Cut | 17 Nov |
| Evening "anything different today?" | Cut | 17 Nov |
| Checkpoint reviews (weeks 6, 14, 20) and stall flag prompt Claude | Partial | Flags exist in `CoachReview`; shown only on Progress; no Today line (C2) and no notification |

### Improvement and adjustment
| Capability | Status | Evidence |
|---|---|---|
| Calories from the 2-week weight trend, within Advisor limits | Built (core) | `CalorieRules.swift`, tests |
| Meal plan follows the moved target | Built | `MealsHubView` passes the engine's kcal target to `MealPlan` |
| Loads progress within Phase 1 (reps → sets → tempo → weight, 24 kg flag) | Built | `Progression.swift`, tests |
| Volume drops on low recovery | Built | two "Sore" answers |
| You can see what changed and why | **Missing** | No screen explains a target or load change |
| Phases 2 and 3 (weeks 7–20) | **Missing** | only `phase-1.json`; board C5 in progress |
| Progression carried across phases | **Missing** | board C6 in progress |
| One end-to-end test of the whole loop | **Missing** | board C1 in progress |
| Return after a missed week or illness eases loads | **Missing** | progression holds loads, never lowers them |
| Claude summary and import, rejected safely when bad | Built | `CoachSummary`, `CoachImport`, UI tests A17 |

### Grocery list
| Capability | Status | Evidence |
|---|---|---|
| Weekly top-up list: merged, aisle order, staples once | Built | `MealsHubView`, M3-03 tests |
| Search link per item to the default shop | Partial | Waitrose hard-coded in `recipes.json`; the plan's D6 says "asked before the first list" |
| Recipe box for 3–4 weeknights, app plans the rest | Built | |
| In-store mode | **Missing** | |
| Delivery-slot reminder | **Missing** | `CoachNotifications` has morning brief, leave now, wind-down, Sunday prompt only |
| Share the list (partner, Reminders) | **Missing** | not in plan; market norm (§3) |
| Enough recipes to avoid repetition over 20 weeks | Partial | 19 recipes in total |
| Office lunch list, one suggestion, "Another" | Built | |
| Social meals (2 a week planned in) | Cut | returning as board C4 |

### Survey and preferences
| Capability | Status | Evidence |
|---|---|---|
| Onboarding with defaults, under 5 min | Built | 12 editable pre-filled rows, two taps to confirm |
| Modules G (shop, delivery slot) asked before the first list; H (office food) on first office day | **Missing** | |
| Everything editable later in Settings → Preferences, re-plans from tomorrow | **Missing** | no Settings screen in `App/` |
| Permissions screen, each with one line on why | Built | `PermissionsView.swift` |

### Easy design
| Capability | Status | Evidence |
|---|---|---|
| Design direction, declutter pass, one big button per screen | Built | `docs/design/direction.md`, UI-12 |
| Full session touching only Next and Done | Built | UI test |
| Measured ease: taps and seconds per daily job | **Missing** | never measured |
| App icon | **Missing** | |
| Open taste decisions (accent, dark, numerals) | Partial | defaults built, CEO not yet shown in one place |

### Photos and progress
| Capability | Status | Evidence |
|---|---|---|
| Front and side photos every 2 weeks, on the phone only | Built | `PhotoDayView.swift` |
| Photo-day notification | **Missing** | not in `CoachNotifications` |
| Ghost outline to line up against | Cut | 17 Nov |
| Compare photos over time | **Missing** | Progress lists 72×96 thumbnails by date |
| Any analysis of the photos | **Missing** | never planned |
| Weight trend (7-day average), strength by lift | Built | Progress |
| Real scale data, camera on the phone | Deferred | paid account |

### Other plan items not built
Hyde Park run loops (plan §4.2): **Missing**. Checkpoint notification (§4.7): **Missing**. Everything under "Deferred to payment" on the board stays deferred.

## 3. Market check: how comparable apps do it

| App | What it does well | What we take |
|---|---|---|
| **MacroFactor** | Weekly check-in on a chosen day. The app recommends new calorie and macro targets from the weight trend and logged intake; you accept or decline. A "Fast Check-In" applies it in one tap. Expenditure estimate updates continuously; median error ~110 kcal/day after 100 days. | Check-in on the set day, numbers pre-filled, one tap to accept. We have no food log by design, so the scale trend alone drives it (already the Advisor model). |
| **Fitbod** | Per-muscle recovery score (0–100%, full recovery up to 7 days); easy sets raise load, struggled sets ease it; **lowers weights after training breaks**; periodic max-effort days. | Return-from-break easing. The visible "last time → today" (C6). We keep fixed programmes, not generated workouts: less to think about. |
| **Online coach check-in forms** (HubFit, CoachWay templates) | 10–12 fixed questions: average weight, sessions vs planned, days on plan, steps, energy 1–10, sleep, stress, pain, photos, one win and one obstacle. Same order every week, coach makes one change. | Fixed order, numbers auto-filled from the app, only 3 one-tap feel questions. Skip the free-text ones (admin). |
| **Progress photo apps** (Metamorph, Progress, GainFrame) | Auto-alignment and overlays, side-by-side, GIF/timelapse export. Metamorph keeps photos on the device or own iCloud. AI "physique scores" (GainFrame Pro) send photos to a cloud AI service. | Overlay, alignment check and compare slider, all on the phone. Not cloud scoring. |
| **Meal planners** (Mealime, Paprika, Plan to Eat) | Lists auto-merge and sort by aisle; pantry tracking; share lists with a household. | We already merge and sort. Add sharing to Apple Reminders (shared list with the partner) and an in-store mode. |

**Photo body-fat evidence.** The best published phone-camera method (a 2022 validation study against DXA, 134 adults, sponsor-authored) had a mean absolute error of about 2.2 percentage points, with limits of agreement of about −5.5 to +4.7 points. The CEO's whole goal is roughly 20% → 10–12%, about 1.5 points a month. A number with ±5 points of noise would bounce around the real change and mislead. Consumer apps that score physiques are not validated at all, and they send photos to a server.

Sources: [MacroFactor check-ins](https://help.macrofactorapp.com/en/articles/247-introduction-to-check-ins-and-coaching-modules), [MacroFactor algorithm accuracy](https://macrofactor.com/algorithm-accuracy/), [How Fitbod creates your workout](https://help.fitbod.me/hc/en-us/articles/360004429814-How-Fitbod-Creates-Your-Workout), [HubFit weekly check-in template](https://hubfit.com/blog/weekly-check-in-form-template-for-online-coaches-and-personal-trainers), [Progress photo apps compared (vendor-written)](https://gainframe.app/blog/best-progress-photo-apps/), [Smartphone camera adiposity validation study](https://pmc.ncbi.nlm.nih.gov/articles/PMC9243018/), [Apple Vision body pose](https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest).

## 4. Each request validated

Judged against the guiding rule (no thinking or admin time), the privacy rule (health data and photos stay on the phone, iCloud and summaries the CEO chooses to share with Claude) and £0 for services.

### 4.1 Check-ins: **keep, adjusted**
One Sunday screen that folds the existing Sunday prompt and a check-in together, about 60 seconds. The app fills in the numbers (7-day weight average and change, sessions done of planned, average steps). Three one-tap questions with a pre-selected middle answer: energy, sleep, any pain. Then "Next week" shows the changes (calories, loads, sessions) and one **Looks good** button. Skipping it changes nothing and the plan still runs. **Rejected:** free-text win/obstacle questions and daily check-ins (admin).

### 4.2 Improvement: **keep**
The engine exists; the gap is that it's invisible and stops at week 6. Finish C1–C6, then add a "What changed and why" card (one line per change, e.g. "Calories 2,000 → 1,900: weight flat for 2 weeks"), and Fitbod-style easing after a missed week. **Rejected:** generating workouts on the fly; fixed programmes are less to think about and the Advisor has reviewed them.

### 4.3 Grocery list: **keep, adjusted**
The core is right. Add: choice of shop asked once before the first list (Waitrose, Ocado, M&S, Tesco, Sainsbury's search links), one-tap send to an Apple Reminders list (shareable with the partner; Reminders groups groceries itself), in-store mode (big ticks, aisle order, screen stays on), a delivery-slot reminder, and more recipes so a dinner doesn't repeat within 3 weeks. **Rejected:** filling a supermarket basket automatically (no public API; out of scope in the plan).

### 4.4 Survey: **keep, adjusted**
Don't make onboarding longer. Add **Settings → Preferences** with every survey module (A–J) editable, each change re-planning from tomorrow. Ask the shop module before the first list, office food on the first office day. **Rejected:** a longer upfront questionnaire.

### 4.5 Easy design: **keep, made measurable**
Set a budget per daily job and test against it in UI tests: start today's session 1 tap from launch; tick off a meal change 2 taps; Sunday check-in under 60 s; photo day under 60 s; find the shopping list 1 tap. Designer runs a heuristic walk of every screen against the budget; QA times it. Add an app icon. Taste decisions stay as defaults and go to the CEO in one batch (design-loop rule).

### 4.6 Photo analysis: **adjust**
**Rejected:** an AI body-fat percentage or physique score. Cloud services break the privacy rule and cost money; the best evidence gives ±5 points of noise, bigger than the change being measured.
**Build instead, all on the phone (Apple Vision, no network):**
- **Ghost outline** of the first photo while shooting, brought back from the cut list.
- **Alignment check** with on-device body-pose detection: "step back a little" or "turn a bit more" before the shutter, so photos are comparable.
- **Compare view:** today against week 0 and against 4 weeks ago, with a slider.
- **Changes in numbers that are trustworthy:** shown next to the photos: weight trend, and an optional waist measurement every 2 weeks if the Advisor agrees it's worth 20 seconds.
- **Claude, by choice only:** the summary never includes photos. If the CEO wants Claude's opinion on photos, he attaches them himself from the share sheet. The app never sends them. *Flagged:* the camera parts need the phone (paid account) to prove; the simulator proves them with library images.

### 4.7 Buying groceries through a retailer (Amazon, Tesco, Sainsbury's, Ocado): **adjust**
Added at the CEO's request at 07:48. Finding: **no UK grocer offers a public way for a personal app to fill your basket.**

| Route | What exists | Verdict |
|---|---|---|
| Tesco, Sainsbury's, Ocado, Waitrose, M&S official API | None for customers. Shoppable-recipe partnerships exist (e.g. Whisk, now Samsung Food, with Sainsbury's) but they are business deals, not open to a personal app | Not available |
| Unofficial basket automation (open-source tools for Tesco, Sainsbury's, Ocado) | Works by logging in as you with your password or browser cookies; their own docs say it "may conflict with retailer terms", sessions expire, Ocado checkout is blocked by bot protection | **Reject:** stores your shop login, breaks terms, breaks without warning |
| Amazon fresh groceries | Same-day fresh grocery delivery launched in parts of Central and East London in June 2026; free for Prime over £20, £5.99 otherwise. W2 coverage needs checking at order time | Possible for staples |
| Amazon multi-item cart link | Amazon's "Add to Cart form" fills a basket with several products and quantities in one link, then you check out on Amazon. It needs each product's Amazon ID mapped once, and officially an Associates tag (free account, needs approval) | **Spike** (N11) |
| Per-item search link to your chosen shop | Built (Waitrose); shop choice comes with N4 | Keep |
| Apple Reminders shared list | Free, on the phone, shareable with your partner | Build (N5) |

**Recommendation:** keep the low-admin route that works today, and test Amazon as the one real "fill my basket" option.
1. The recipe box already covers 3–4 dinners with zero shopping.
2. The top-up list goes to a shared Reminders list in one tap, with search links to your chosen shop (N4, N5).
3. **N11 Amazon basket spike (half a day):** map the ~25 recurring staples (eggs, yogurt, chicken, oats, rice, creatine and so on) to Amazon products once; "Fill Amazon basket" opens Amazon with this week's staples and quantities in the basket, and you check out yourself. Only if the link works without a paid service and fresh delivery reaches W2. If either fails, it's dropped and the list stays.

**Privacy:** only ingredient names and quantities leave the phone, and only when you tap. No calories, weights, health data or account logins. **Cost:** £0 from us; Amazon delivery fees are yours if you use it. **Approval:** an Amazon Associates account is free but is an account in your name, so it goes through the Setup Desk only if the spike shows it's needed.

Sources: [Amazon fresh groceries in London](https://www.aboutamazon.com/news/retail/amazon-grocery-same-day-delivery-uk), [Amazon Add to Cart form](https://webservices.amazon.co.jp/paapi5/documentation/add-to-cart-form.html), [Whisk and Sainsbury's partnership](https://www.businesswire.com/news/home/20210126005433/en/Whisk-Adds-Sainsburys-to-Partner-Ecosystem-to-Enable-Shoppable-Recipes-Across-the-UK), [open-source UK grocery automation and its caveats](https://github.com/abracadabra50/uk-grocery-cli).

## 5. Build plan

Two waves. Wave 1 is the board's C1–C6, already in progress, due 17:00 today. Wave 2 is new. Times are London (GMT).

**Honest ETA: the whole of wave 2 merged by 18:00 on 19 Nov; a full QA round (core changes) and the Advisor's co-sign by 15:00 on 20 Nov; a CEO pack by 20:00 on 20 Nov.** That is a day later than a "one more day" estimate, because the full QA round can't start until both waves are in and Today, Meals and Progress are each touched by several items. Risk: merge conflicts on `TodayView` and `MealsHubView`; HoE sequences merges by screen.

**Cut rule if it slips:** drop N11 (Amazon spike) and N10 (run loops) first, then in-store mode in N5, then the compare slider in N7 (keep side-by-side).

### Wave 1 (in progress, unchanged)
C1 coach loop test · C2 Today stall line · C3 meals follow the target · C4 social meals · C5 Phase 2 and 3 programmes · C6 progression across phases. Done when lines on `docs/board.md`.

### Wave 2

| ID | Item | Owner | Label | Depends on | ETA |
|---|---|---|---|---|---|
| N1 | Sunday check-in (folds in the Sunday prompt) | Planner Engineer (core), iOS Interface Engineer (screen) | core | C1, Advisor A1 | 19 Nov 14:00 |
| N2 | "What changed and why" card | Coach Engineer (core), iOS Interface Engineer | core | C1 | 19 Nov 12:00 |
| N3 | Settings → Preferences (all survey modules, re-plan from tomorrow) | iOS Interface Engineer, Planner Engineer (re-plan) | core | — | 19 Nov 16:00 |
| N4 | Ask-when-needed: shop choice before first list, office food on first office day | Planner Engineer, iOS Interface Engineer | core | N3 | 19 Nov 18:00 |
| N5 | Grocery: send to Reminders, in-store mode, delivery reminder | iOS Interface Engineer, Planner Engineer (notification) | interface | N4 | 19 Nov 18:00 |
| N6 | Recipe variety: no dinner repeats within 3 weeks | Researcher (Advisor reviews) | docs | — | 19 Nov 12:00 |
| N7 | Photos: ghost outline, on-device alignment check, compare view, photo-day notification | iOS Interface Engineer | interface | Advisor A3 | 19 Nov 18:00 |
| N8 | Return-after-a-break easing | Planner Engineer | core | Advisor A2 | 19 Nov 12:00 |
| N9 | Ease budget: tap and time budget, heuristic walk, UI tests, app icon | Product Designer (spec), iOS Interface Engineer, Head of QA | interface | — | spec 19 Nov 10:00; fixes 19 Nov 18:00 |
| N10 | Checkpoint notification and Hyde Park run loops | Planner Engineer, Researcher (loops) | core | — | 19 Nov 18:00 |
| N11 | Amazon basket spike (staples only) | Planner Engineer (link), Researcher (product mapping) | interface | N5 | 19 Nov 16:00 |
| QA-R4 | Full round on one build (core changed) | Head of QA, Advisor co-signs | docs | all | 20 Nov 09:00–15:00 |

### Done when

**N1 · Sunday check-in**
- On the profile's check-in day, Today shows one Check-in card; the screen opens with weight average and change, sessions done of planned, and average steps already filled in.
- Energy, sleep and pain are one tap each with a pre-selected default; a UI test finishes the whole check-in, office days included, in under 60 s of taps.
- "Looks good" applies the week's changes; skipping leaves the plan running unchanged (CoachCore test).
- Answers go into the Claude summary; low energy or pain on two check-ins feeds the existing drop-to-2-sessions rule only as the Advisor sets (A1).

**N2 · What changed and why**
- After any calorie, load or session change, Progress and the check-in show one line per change with its reason, e.g. "Calories 2,000 → 1,900: weight flat for 2 weeks".
- A CoachCore test produces the right lines for a calorie drop, a load rise, a dumbbell-limit flag and an imported Claude block.
- No card when nothing changed.

**N3 · Settings → Preferences**
- A Settings entry in the ⋯ menu lists every onboarding module (A–J), each editable with its current value shown.
- Saving any change re-plans from tomorrow, never mid-day (CoachCore test), and keeps today's alarms.
- The check-in day and time set here is the one N1 uses (the dead setting goes live).

**N4 · Ask when needed**
- Before the first shopping list, one screen asks for the shop and delivery slot, defaulting to Waitrose and Sunday; search links follow the choice.
- On the first office day, the lunch card asks once for max walk and dislikes, with defaults; skipping uses the defaults.
- Both answers appear and are editable in Preferences.

**N5 · Grocery**
- "Send to Reminders" writes the week's top-up list to one Reminders list (created once, reused), with quantities; a UI test sees the list after granting access.
- In-store mode shows only unticked items in aisle order, large rows, with the screen kept awake.
- A delivery-slot reminder fires the day before the chosen slot, outside quiet hours (unit test).

**N6 · Recipe variety**
- Enough recipes that a 3-week rotation has no repeated dinner; content validation passes.
- Every new recipe is 2 portions, no raw fish, no batch cooking, with calories and protein; the Advisor signs off.
- The meal-plan tests at 1,850, 2,000, 2,200 and 2,450 kcal still pass.

**N7 · Photos**
- On photo day, a translucent outline of the first photo of that pose sits over the viewfinder (library-image stand-in in the simulator).
- On-device body-pose detection shows one plain hint when the pose or distance is off; no network call is made (test with network disabled).
- Progress opens a compare view of today against week 0 and against 4 weeks ago, with a slider.
- A photo-day notification fires every 2 weeks outside quiet hours; the Claude summary still contains no photos.

**N8 · Return after a break**
- After 10 or more days without a strength session, the next session's loads ease by the amount the Advisor sets (A2), then rebuild over the following sessions (CoachCore test).
- The player shows why ("Easing back in after 12 days off").
- Normal weeks are unchanged (existing progression tests pass).

**N9 · Ease budget**
- `docs/design/ease-budget.md` lists each daily job with its tap and time budget (start session 1 tap; Sunday check-in 60 s; photo day 60 s; meal change 2 taps; shopping list 1 tap).
- A UI test per job asserts the budget; any job over budget is fixed or recorded with a reason.
- The app has an icon.

**N10 · Checkpoint notification and run loops**
- A notification on the evening each checkpoint falls due, outside quiet hours (unit test).
- The run-walk player names a Hyde Park loop that matches the session's distance, from a small data file.

**N11 · Amazon basket spike**
- `docs/spikes/s5-amazon-basket.md` records whether a multi-item cart link opens amazon.co.uk with the right items and quantities without a paid service, and whether fresh delivery reaches W2.
- If yes: "Fill Amazon basket" on the Shopping tab opens Amazon with this week's mapped staples and quantities; unmapped items stay on the list.
- Only ingredient names, product IDs and quantities are in the link (test); no login is stored.
- If no: the button is not shipped and the spike note says why.

## 6. Advisor review (safety-relevant parts)

Sent to the Advisor on 18 Nov. Each answer will be folded in as accepted, changed or rejected before N1, N7 and N8 start.

- **A1 · Check-in questions.** Are energy, sleep and pain the right three? Which answers may change the plan by themselves, and which only go to Claude?
- **A2 · Return after a break.** Threshold (10 days?) and how much to ease loads, and over how many sessions to rebuild.
- **A3 · Photo analysis.** Agree to reject a photo body-fat score? Is an optional waist measurement every 2 weeks worth its 20 seconds?
- **A4 · Recipe variety.** Any constraint beyond the existing floors for the new recipes.

Advisor's answers: *pending*.

## 7. Open decisions (for the CEO's next review, not asked now)

- Whether to allow attaching photos to a Claude check-in at all (default: the app never does; the CEO can share himself).
- The taste defaults (accent, always dark, numerals, icon), batched once.
- Payment for the Apple account still gates every on-phone proof, including the camera parts of N7.
