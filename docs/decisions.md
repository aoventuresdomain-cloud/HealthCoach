# Decisions

Newest first. The plan (`fitness-coach-project-plan.md`) wins over this file where they differ; anything here that changes the plan is noted.

| Date | # | Decision | Made by | Notes |
|---|---|---|---|---|
| 2026-11-16 | E1 | Bundle IDs `com.aoventures.healthcoach` (app) and `com.aoventures.healthcoach.LiveActivity` (widget). Store name "HealthCoach", falling back to "HealthCoach AO" if App Store Connect says it is taken (names are unique across the store) | Head of Engineering | Needed by the Setup Desk for App Store Connect. Cheap to change until the app record exists |
| 2026-11-16 | D7 | Standing order: the team takes the product to Gate 2 (Checkpoint 1, end of week 6) without asking the CEO anything. Gates 0a and 1 are internal (Head of QA + Advisor). CEO time is 0 h a week until Gate 2. Payment: "I'll say when" | CEO | Supersedes the 2 h weekly cap until Gate 2 |
| 2026-11-16 | E4 | CI runs on GitHub Actions hosted macOS (free private-repo minutes, £0 spending limit): simulator builds, CoachCore tests, screenshots. It replaces Xcode Cloud until payment | Head of Engineering | Not a paid service |
| 2026-11-16 | E5 | Default shop for top-up links is Waitrose (plan §12's comparison shop), swappable in Settings. The delivery-slot reminder defaults to Sunday 18:00 | Head of Engineering | Plan D6 said "ask before the first list"; deferred to the CEO's first run, with a default in place |
| 2026-11-16 | E6 | Onboarding is pre-filled from the requirements draft §12 defaults and plan §2. The CEO confirms them on first install | Head of Engineering | |
| 2026-11-16 | E7 | Device-only Done when lines are replaced by simulator or UI-test checks; the device versions are listed under "Deferred to payment" on the board | Head of Engineering | |
| 2026-11-16 | E8 | Design loop without a CEO round: the CEO's stated views in the requirements draft win, and open taste decisions are held for Gate 2 | Head of Engineering | |
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
