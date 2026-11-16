# Decisions

Newest first. The plan (`fitness-coach-project-plan.md`) wins over this file where they differ; anything here that changes the plan is noted.

| Date | # | Decision | Made by | Notes |
|---|---|---|---|---|
| 2026-11-16 | E1 | Bundle IDs `com.aoventures.healthcoach` (app) and `com.aoventures.healthcoach.LiveActivity` (widget). Store name "HealthCoach", falling back to "HealthCoach AO" if App Store Connect says it is taken (names are unique across the store) | Head of Engineering | Needed by the Setup Desk for App Store Connect. Cheap to change until the app record exists |
| 2026-11-16 | D4a | Paid Apple Developer account **on hold** until there is a more material product. No Xcode Cloud or TestFlight for now; CI moves to GitHub Actions (free tier) with simulator builds. Proposed pay trigger: M1 running end to end in the simulator | CEO (hold); Head of Engineering (route) | Supersedes D4 for now. On-phone spikes become M0b, after payment |
| 2026-11-16 | E3 | The repository is `HealthCoach`, not `fitness-coach` as plan §13 says; the layout inside is the plan's | Head of Engineering | Setup Desk confirmed the repo |
| 2026-11-16 | E2 | CoachCore uses the standard SwiftPM `Sources/` + `Tests/` layout; Swift Testing for tests | Head of Engineering | Same content as plan §13, conventional paths |
| 2026-11-16 | D1 | Goal: lean, strong and defined over 16–20 weeks in three phases; checkpoints at weeks 6, 14 and 20 | CEO | Plan §2 |
| 2026-11-16 | D2 | Claude reviews at checkpoints and on stall flags via share and import, plus an "Ask the coach now" button | CEO | Confirms the plan's cadence change |
| 2026-11-16 | D3 | Equipment: adjustable dumbbells to ~24 kg, bench, pull-up bar, Health scale | CEO | Plan §3 |
| 2026-11-16 | D4 | Paid Apple Developer account; Xcode Cloud builds every change, TestFlight installs it | CEO | Free-sideload fallback (plan §6) no longer applies |
| 2026-11-16 | D5 | Never forward work calendar invites; the Sunday prompt is the default calendar route | CEO | Closes spike S2 (board M0-07) |
| 2026-11-16 | D6 | Recipe box for 3–4 weeknight dinners from week 1 | CEO | Plan §4.3 |
| 2026-11-16 | — | CEO already training from the paper Week 1 plan. Start with M0; ask the CEO nothing else until Gate 0 unless blocking | CEO | |
