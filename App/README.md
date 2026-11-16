# App

SwiftUI app target `HealthCoach` (iOS 26+, iPhone only): Today screen, workout player, onboarding, settings.

- Project: `HealthCoach.xcodeproj` at the repo root. This folder is a folder-synced group, so any file added here joins the app target with no project edits. `Info.plist` and this README are excluded from the bundle.
- `Info.plist` holds only the keys Xcode can't generate (`NSAlarmKitUsageDescription`, `NSSupportsLiveActivities`, `ITSAppUsesNonExemptEncryption = NO`); the rest is generated from build settings.
- Links the local `CoachCore` package and embeds the `LiveActivity` extension.
- `../Shared/` is compiled into both this target and `LiveActivity` (ActivityKit attributes).
