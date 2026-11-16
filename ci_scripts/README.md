# ci_scripts

Xcode Cloud hooks (`ci_post_clone.sh`, `ci_pre_xcodebuild.sh`, `ci_post_xcodebuild.sh`). Xcode Cloud only finds them in a folder named `ci_scripts` next to the Xcode project; `HealthCoach.xcodeproj` sits at the repo root, so this is the right place. Scripts must be committed executable (`chmod +x`). Owner: Planner Engineer.

Never commit signing certificates, API keys or App Store Connect credentials. Xcode Cloud manages signing.
