# App

SwiftUI app target `HealthCoach` (iOS 26+, iPhone only): Today screen, workout player, onboarding, settings.

- Project: `HealthCoach.xcodeproj` at the repo root. This folder is a folder-synced group, so any file added here joins the app target with no project edits. `Info.plist` and this README are excluded from the bundle.
- `Info.plist` holds only the keys Xcode can't generate (`NSAlarmKitUsageDescription`, `NSSupportsLiveActivities`, `ITSAppUsesNonExemptEncryption = NO`); the rest is generated from build settings.
- Links the local `CoachCore` package and embeds the `LiveActivity` extension.
- `../Shared/` is compiled into both this target and `LiveActivity` (ActivityKit attributes).

## Data and testing (M1-01)
- `Data/ProfileStore.swift`: the one profile record in SwiftData (`ProfileRecord`), stored as CoachCore's versioned `Profile` JSON. CoachCore owns the format and its migrations.
- `Testing/`: Debug-only launch flags for UI tests (`-uitest`, `-now <ISO date>`, `-fixture <name>`, see `docs/qa/test-plan.md` §3), `AppClock` (the one clock handed to CoachCore), the fake alarm registrar, and `Fixtures/fixture-<name>.json`.
- UI tests live in `../HealthCoachUITests/` (folder-synced target in the shared scheme). Give every control a stable `accessibilityIdentifier`; tests never match on copy.
