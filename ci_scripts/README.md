# ci_scripts

Xcode Cloud hooks (`ci_post_clone.sh`, `ci_pre_xcodebuild.sh`, `ci_post_xcodebuild.sh`). Xcode Cloud only finds them in a folder named `ci_scripts` next to the Xcode project, so M0-02 may move this folder when the project lands. Owner: Planner Engineer.

Never commit signing certificates, API keys or App Store Connect credentials. Xcode Cloud manages signing.
