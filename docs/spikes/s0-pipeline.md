# S0 · Pipeline to the phone (board M0-03)

**Status:** waiting on Setup Desk Parts A–C. Owner: Planner Engineer.

## How it works
1. A PR merges to `main`.
2. Xcode Cloud (workflow from Setup Desk Part B) clones, runs `ci_scripts/ci_pre_xcodebuild.sh`, which runs `swift test` in `CoachCore` before the archive. A failing test exits non-zero, the build fails, and nothing is uploaded.
3. The archive is uploaded to App Store Connect; the internal TestFlight group "Me" (automatic distribution) gets it.
4. TestFlight on the iPhone (Automatic Updates on) installs it. No owner steps after the one-off setup.
5. A weekly scheduled build keeps a build younger than TestFlight's 90-day expiry.

## Measurements (fill from the first three builds)
| Build | Merged (UTC) | Xcode Cloud start → end | Minutes used | On phone | Push → installed |
|---|---|---|---|---|---|
| | | | | | |

**Monthly estimate:** builds per month × minutes per build = ___ of the 25 included hours.

## Test gate check
- [ ] A deliberately failing CoachCore test on a throwaway branch fails the Xcode Cloud build and no TestFlight build appears. (Run once, with a branch start condition, then delete the branch.)

## Findings
_To be written after the first builds._
