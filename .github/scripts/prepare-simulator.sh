#!/bin/sh
# Boots the simulator and sets it to the CEO's phone settings: British English,
# en_GB region, 24-hour clock (QA-4). Run in the background while the app
# builds, so the boot (about 3 minutes cold) overlaps the compile. Writes
# sim-ready when done; wait-simulator.sh waits for that file.
set -eu
udid="$1"
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b
xcrun simctl spawn "$udid" defaults write -g AppleLocale -string en_GB
xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array en-GB
xcrun simctl spawn "$udid" defaults write -g AppleICUForce24HourTime -bool YES
# Restart so every process (including SpringBoard) picks up the new locale.
xcrun simctl shutdown "$udid"
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b
touch sim-ready
