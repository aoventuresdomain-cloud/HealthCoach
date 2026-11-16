# Fitness Coach: project plan (hand-off)

*Idea Lab hand-off · 16 Nov 2026 · Version 2.1, final (Advisor confirmed) · Open owner decisions: D4 developer account, D3 kit, D2 Claude cadence. The start-here guide's first message records whichever way they go. Supersedes 00-requirements-v1-owner-draft.md for build purposes; the draft's onboarding tables (§12) still hold except where this plan changes them.*

## 1. Summary

A personal iPhone coach that tells you what to do and when, so you never have to think about it. On Sunday you answer one 20-second question about office days. The app then places your sessions, sets a week or two of alarms ahead, plays each workout with GIFs, cues and a lock-screen timer, plans meals around a recipe box, and reads your weight from a smart scale. Claude steps in at each phase checkpoint, or when progress stalls.

**Guiding rule:** if it takes thinking or admin time, it has failed.

**Recommendation:** a native SwiftUI app, distributed through a paid Apple Developer account. Claude writes the code, Xcode Cloud builds it and TestFlight installs it on your phone. You never plug the phone into the Mac. Start training this week from the paper Week 1 plan (§2). The app takes over from about week 2.

**Who:** one user (the owner). Data is kept in one versioned profile record, so the app can open up later. Nothing else is built for other users.

## 2. Goal and phases

- **Start:** male, 30, 178 cm, 82 kg, ~18–22% body fat, active in the past, sedentary lately. Basketball every Wednesday. Can run 2 km at 6:00/km.
- **End goal:** lean, strong and defined, with abs visible in good light. That is ~10–12% body fat, about 75–76 kg, and takes **16–20 weeks**, not 6.

| Phase | Weeks | Aim | Calories | Training |
|---|---|---|---|---|
| 1. Cut and rebuild | 1–6 | −3 to −4 kg, fitness back | ~2,000 kcal | Weeks 1–3: 3 strength + 1 run-walk + basketball. Weeks 4–6: second run added |
| Checkpoint 1 | end of 6 | Claude review | — | — |
| 2. Cut | 7–12 | −2.5 to −3 kg | adjusted from the weight trend | full plan, load rising |
| Maintenance break | 13–14 | Recover, hold weight | ~2,400–2,500 kcal | same plan, load held |
| Checkpoint 2 | end of 14 | Claude review | — | — |
| 3. Final cut | 15–20 | Abs visible in good light | adjusted | full plan |
| Checkpoint 3 | end of 20 | Maintain, keep going or build | — | — |

- **Protein:** 160 g a day, about 40 g at each of four eating moments, loosely tracked.
- **Paper Week 1 (start now, before the app):** Mon upper A, Tue run-walk (1 min easy jog / 1 min walk × 10), Wed basketball, Thu full-body with light legs, Sat upper B, Sun rest or a walk in Hyde Park. Eat around 2,000 kcal with protein at every meal, and step on the scale each morning once it arrives.

## 3. Equipment (D3, reconciled)

Buy these now, so 12.5 kg never caps progress:

| Item | Why | Approx. cost |
|---|---|---|
| Quick-change adjustable dumbbells to ~24 kg each | The biggest single lever on strength and shape. A dial changes the weight in seconds, so there's no faff between sets | £250–400 |
| Adjustable flat/incline bench | Upper body is the priority; floor pressing caps chest and shoulder range | £80–150 |
| Doorframe pull-up bar (resistance bands if the frame can't take one) | Pulling is what dumbbells cover worst | £25–40 |
| Smart scale that syncs to Apple Health | Replaces the manual weigh-in; the 7-day average beats one weekly number | £40–100 |

A gym stays optional. The app flags when the dumbbells next become the limit.

## 4. What the app does

### 4.1 Daily planner and alarms
- **Sunday prompt (20 seconds):** which days you're in the office, plus any early starts or late finishes. If IT later allows the work calendar on the phone, the app reads busy times only, and the prompt disappears.
- From that, the app places each session in the morning or evening slot. Basketball is fixed on Wednesday. Sunday is the long slot.
- **Wake time** = first commitment − commute − shower − session − buffer, protected by a 7.5–8 h sleep target.
- **Alarms are pre-registered 7–14 days ahead** through AlarmKit every time the app opens, after the Sunday prompt and after every app update (it checks what's registered against the plan and fills any gaps). There is no nightly background job. Alarms already registered fire even if the app never runs again. A one-tap "tomorrow changed" re-plans one day.
- **Weather** (Open-Meteo, free) is checked when the morning brief opens. Bad weather swaps an outdoor run for an indoor session of the same length, so the wake time never moves. "I'll run anyway" is one tap.
- **Today screen:** one timeline: wake, session, breakfast, leave, lunch order, dinner, wind-down, bed.

### 4.2 Workouts
- Phase programmes are stored as data files, with the ramp in §2. There are two upper sessions and one full-body session with light legs, kept away from basketball day. No session is designed to leave you sore on the stairs.
- **Workout player:** a GIF per exercise (front or side) and three callouts (setup, movement, common mistake). It has a rest timer, voice countdowns through headphones, a big tap rep counter (you asked for tap and voice), and a Live Activity on the lock screen and Dynamic Island.
- **Logging is one tap:** "done as prescribed". You only edit when something differed.
- **Progression rules:** add reps, then sets, then tempo, then weight, and flag when the dumbbells become the limit. The week drops to 2 strength sessions if soreness or the optional mood log is low twice.
- **Runs:** guided run–walk intervals with voice cues, building to a continuous 5 km, on suggested Hyde Park loops. Distance and time come from the phone.
- Cut from v1: the HIIT builder.

### 4.3 Nutrition
- **The recipe box covers 3–4 weeknight dinners for two** from week 1. The app records each box night at its per-portion calories and protein.
- The app plans everything else: 3–4 high-protein breakfasts on rotation, quick home-day lunches, and one longer Sunday cook. Every recipe makes exactly two portions, with no raw fish and no batch cooking.
- **Tracking:** planned meals are pre-ticked. One evening question, "anything different today?", covers changes. You never weigh food.
- **Social eating default:** 2 social meals a week are planned in and not tracked. You can change this.
- **Supplements:** the basics only: creatine; vitamin D in the UK winter, as the NHS advises; protein powder only on days you're short of protein.

### 4.4 Shopping
- One weekly top-up list for everything the box doesn't cover. Quantities are merged, items are sorted by aisle, and pantry staples are ticked off once.
- Each item has one search link to your default shop. There's an in-store mode, and a reminder to book or confirm your delivery slot.
- Cut: routing each food category to a different shop. It comes back only if shopping starts to hurt.

### 4.5 Office lunch
- A fixed list of 5–6 protein-forward orders within an 8-minute walk of St James's Market. Each has the order, approximate calories, protein and price.
- The list is curated once during the build. On office days the app suggests one order, and you swipe for another. You can swap any entry in Settings.

### 4.6 Coach and progress
- **Rules engine (on the phone, weekly, automatic):** sets calories from the 7-day weight trend, load from the logs, and volume from recovery.
- **Claude (on your existing subscription):** at each phase checkpoint, and whenever the engine flags a stall (for example, 2 weeks with no weight change). The app builds a summary and opens the Claude app with one tap. You copy Claude's reply and tap **Import**: the app reads the clipboard, checks the versioned block, and applies it from tomorrow. A bad block is rejected with a plain message, and last week's plan stays. An **"Ask the coach now"** button allows a check-in any time. *(This changes D2's cadence from weekly. It's your call.)*
- **Progress:** a weight trend line (7-day average from Health), strength by lift, and front and side photos every 2 weeks with a ghost outline to line up against.
- **Mood:** an optional one-tap daily check. Skipping it changes nothing.

### 4.7 Notifications
Local notifications only: morning brief, "leave now", delivery-slot reminder, Sunday prompt, photo day every 2 weeks, checkpoint, and bedtime wind-down. Quiet hours are 22:30–06:00.

## 5. Integrations

| Need | Route | Cost |
|---|---|---|
| Alarms | AlarmKit (iOS 26+). Needs only the `NSAlarmKitUsageDescription` usage text; there is no special entitlement | £0 |
| Calendar | Sunday prompt by default; iPhone Calendar busy times if IT allows. **Never forward work invites** (D5) | £0 |
| Weather | Open-Meteo, no key | £0 |
| Weight, steps | Apple Health (smart scale writes to it) | £0 |
| Exercise media | ExerciseDB V1 GIFs for ~40 exercises, bundled in the app. Check the licence before any wider release | £0 |
| Groceries | Recipe box + top-up list with search links (Waitrose and Ocado have no public customer API) | food only |
| Coaching | Claude app on the existing subscription, share and import (no API) | £0 |

## 6. Architecture and distribution

- **App:** native SwiftUI for iOS 26+. A widget extension provides the Live Activity.
- **CoachCore:** a Swift package that holds the planner, the rules engine, progression and the import parser. It has no iOS dependencies, so its tests run anywhere, including in Claude's cloud sessions.
- **Data:** SwiftData on the phone, with one versioned profile record. Programmes, recipes and the lunch list are stored as data files.
- **Backup:** the phone's normal iCloud backup. Turn on Advanced Data Protection so progress photos stay end-to-end encrypted. There's no server and no AWS in v1.
- **Distribution (D4, reconciled):** the paid Apple Developer Program (about £79 a year). Claude pushes to a private GitHub repository. Xcode Cloud (25 build hours a month are included with the membership) builds and tests every change and sends it to TestFlight, which updates the app on your phone automatically. A monthly scheduled build stops the 90-day TestFlight expiry from ever biting. A fixed backup Clock alarm stays on for week 1 only.
- **If you keep free sideloading instead:** SideStore with a 7-day refresh, and each new build installed from the Mac by hand. Spike S0 must then prove that the alarm still fires after the app expires. The switch rule applies: one failed refresh, or a fix taking over 15 minutes, means you pay.

## 7. Milestones and gates

| # | Milestone | Done when | Est. |
|---|---|---|---|
| M0 | Setup and spikes | S0: a push to GitHub reaches the phone through Xcode Cloud and TestFlight with no owner steps. S1: 14 alarms pre-registered; one fires with the phone locked, on Silent and in a Focus mode; the per-app alarm limit is written down. S1b: alarms survive a TestFlight update; if they don't, the app detects missing alarms and re-sets them the next time it opens, and the Today screen shows a warning until it has. S2: calendar route chosen. S3: Live Activity timer with voice cues works on the lock screen. S4: GIFs found for all ~40 exercises | 3–4 days |
| **Gate 0** | **Owner: spikes pass, or fallbacks accepted** | | |
| M1 | Onboarding confirm, Phase 1 programme, Today screen, workout player, one-tap logging, progression | Survey confirmed in under 5 min. A full session completed touching only "next" and "done". Next session's loads change correctly after logging | Week 1–2 |
| M2 | Planner: Sunday prompt, wake times, 14-day alarms, weather swap, notifications, Health weight and steps | Alarms set with no owner action for 7 days running. Sessions placed correctly around basketball and office days. The weight trend reads from the scale | Week 2 |
| **Gate 1** | **Owner: stop using paper; the app runs the week** | | |
| M3 | Meals around the box, breakfasts, Sunday cook, top-up list, lunch list | One full week eaten and shopped from the app with only the evening "anything different?" question | Week 3 |
| M4 | Rules engine, stall flag, Claude summary and clipboard import, progress view, photos with ghost outline | A simulated 2-week stall raises a flag. An imported Claude block changes the next week's plan. A malformed block is rejected safely | Week 4 |
| **Gate 2** | **Owner: Checkpoint 1 at week 6 (first live Claude review)** | | |
| Run | Phases 2–3 are content updates (data files), not new features | Phase 2 and 3 programmes loaded before each phase starts | Weeks 7–20 |

**Owner-time budget:** at most 2 hours a week during M0–M4, mostly Setup Desk steps and gates. After that: about 1 minute on Sunday, 1 minute for photos every 2 weeks, and about 10 minutes at each checkpoint.

**Stop and cut rules:** if the build takes a training slot, or more than 2 hours a week of owner time, cut scope, starting with M3 extras. If the app hasn't replaced the paper plan by the end of week 4, keep the paper plan and finish only the workout player and alarms.

## 8. Out of scope for v1

Travel mode, automated checkout, wearables, Android, multi-user screens, an AWS backend, a paid places API, automatic Claude API calls, tracking your girlfriend's macros (her portions are scaled, not tracked), the HIIT builder, routing shopping by category, and a curated lunch database.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Over-reach in weeks 1–3 (sore shins, legs too tired for the stairs, early drop-off) | Ease-in ramp; light legs until week 4; drop to 2 strength sessions on low recovery |
| Wake alarm doesn't fire | Paid distribution (no expiry), alarms pre-registered 14 days ahead, S1 on your phone, S1b: alarms checked and re-set after every app update, backup Clock alarm in week 1 |
| Building becomes the hobby | 2-hour weekly cap; cut rules; Phases 2–3 are data, not features |
| Week 6 feels like failure | Plan shows phases toward the 16–20 week goal, not a 6-week finish |
| Social eating derails the deficit | Default of 2 planned social meals a week |
| Claude import goes wrong | Versioned block, validation, reject without change |
| Free-signing route (only if D4 is kept) | Switch rule: one failed refresh or a fix over 15 minutes, then pay |
| GIF licence if ever opened to others | Check before any wider release |

## 10. Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Goal: lean, strong, defined | ✅ Kept; extended to 3 phases over 16–20 weeks (Advisor) |
| D2 | Coach: Claude subscription, share and import | ✅ Mechanism kept. **Owner to confirm** the cadence change to checkpoints and stalls, plus "Ask the coach now" |
| D3 | Equipment | **Owner:** dumbbells to ~24 kg, bench, pull-up bar and Health scale (~£450–700). Both views recommend it |
| D4 | Distribution | **Owner:** pay ~£79 a year (both views recommend), reversing the free-sideload decision |
| D5 | Calendar: never forward invites | ✅ Kept |
| D6 | Groceries | Box from week 1 (both views recommend); one default shop for top-ups, asked before the first list |
| D7 | Onboarding survey with defaults | ✅ Kept; module G shrinks to default shop and delivery slot |

## 11. Advisor feedback and what changed

The Independent Advisor reviewed the draft blind (advisor-review-01.md). The full point-by-point answers are in 02-advisor-response-01.md. What changed in this plan:

- **Goal timeline:** 6 weeks became 16–20 weeks in three phases, with a maintenance break. The Phase 1 target narrowed to −3 to −4 kg, and protein is fixed at 160 g.
- **Training load:** the week 1–3 ramp was added (3 strength sessions, 1 run, basketball), with the second run from week 4.
- **Distribution:** the Advisor recommended paying. My switch rule (pay if sideloading fails) merged into one recommendation: pay from day one. While building this in, I found a further reason. Xcode Cloud plus TestFlight puts every build on the phone with no owner steps, which free signing can't do.
- **Equipment:** both views said to buy now. I added a bench to the Advisor's list (dumbbells, pull-up bar, scale).
- **Admin cuts:** one-tap logging, pre-ticked meals, scale instead of manual weigh-ins, photos every 2 weeks, a fixed lunch list instead of a places database, one shop list instead of per-category routing, and the HIIT builder removed.
- **Claude cadence:** weekly became checkpoints and stall flags, with clipboard import. This is flagged for you because it changes D2.
- **Alarms:** a nightly background job became 14-day pre-registration on every app open (more reliable on iOS).
- **Backups:** the manual encrypted export became iCloud backup with Advanced Data Protection.
- **Not taken:** cutting the tap rep counter. You asked for it, and the Advisor doesn't override your stated view.
- **Advisor confirmation (16 Nov 2026):** v2 confirmed with one addition, built in with no further round: spike S1b checks that alarms survive a TestFlight update, and the app re-sets them on next open if they don't (§4.1, M0, risks).

## 12. Cost projection (personal tool, no revenue)

| Item | Low | Base | High |
|---|---|---|---|
| Apple Developer Program | £79/yr | £79/yr | £79/yr |
| Xcode Cloud, GitHub private repo, Open-Meteo, ExerciseDB, Claude | £0 (included or existing) | £0 | £0 |
| Equipment (one-off) | £300 (budget dial dumbbells, basic bench, bar, scale) | £500 | £700 |
| Recipe box, net of the groceries it replaces | £0/week | ~£10/week (£520/yr) | ~£25/week (£1,300/yr) |
| **Year one** | **~£380** | **~£1,100** | **~£2,080** |
| **Year two onwards** | **£79** | **~£600** | **~£1,380** |

- **Key assumptions:** Apple's UK price stays around £79. A recipe box for two costs roughly what the same dinners cost from Waitrose or M&S, plus a convenience premium of £0–25 a week. Xcode Cloud stays within the 25 included hours a month (a build takes about 10–15 minutes).
- **Break-even:** not applicable, because it doesn't earn. The comparison is a personal trainer and nutrition coach in London at roughly £60–100 a session. This plan costs less than two sessions a month in the base case.
- **Main cost risk:** the recipe box. It's a trial, and can be cancelled any week.

## 13. Project layout (repository)

```
fitness-coach/                 private GitHub repo
├── App/                       SwiftUI app: screens, player, onboarding, settings
├── LiveActivity/              widget extension: lock-screen and Dynamic Island timer
├── CoachCore/                 Swift package, no iOS dependencies
│   ├── Planner/               week placement, wake times, alarm schedule
│   ├── Rules/                 calories from trend, progression, recovery, stall flag
│   ├── Import/                versioned Claude block parser and validator
│   └── Tests/                 runs in Xcode Cloud and in cloud sessions
├── Content/                   data files, edited without code changes
│   ├── programmes/            phase-1.json, phase-2.json, phase-3.json
│   ├── exercises/             ~40 exercises with GIF and three callouts
│   ├── recipes/               breakfasts, home lunches, Sunday cooks (2 portions)
│   └── lunch-orders.json      5–6 office orders
├── ci_scripts/                Xcode Cloud hooks
└── docs/                      plan, board.md, decisions.md, handoffs/
```

## 14. Diagrams

See `fitness-coach-blueprint.html` for the swimlane (a normal week: Sunday, night, morning, session, meals, checkpoint) and the architecture diagram (app, CoachCore, iOS services, external services, build pipeline).

## 15. Team (Org Playbook block, filled)

The build project runs as an org: Fitness and Nutrition Advisor, Planner Engineer (core), iOS Interface Engineer, and per-job Training and Nutrition Researcher, QA and Designer. The text to paste is in `fitness-coach-start-here.md`. Core for QA purposes means CoachCore, alarms, Health, data and the Claude import.
