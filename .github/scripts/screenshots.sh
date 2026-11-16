#!/bin/sh
# Simulator screenshots for the Gate 0a pack (board M0-12), using the app's
# `-screenshot <mode>` launch modes (App/Spikes/ScreenshotMode.swift).
# Usage: screenshots.sh <udid> <path to HealthCoach.app> <out dir>
set -eu
udid="$1"; app="$2"; out="$3"
bundle=com.aoventures.healthcoach
mkdir -p "$out"

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 || true
xcrun simctl install "$udid" "$app"

shot() { sleep "$1"; xcrun simctl io "$udid" screenshot "$out/$2.png"; echo "saved $2.png"; }
open_mode() { xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true; xcrun simctl launch "$udid" "$bundle" -screenshot "$1"; }

open_mode spikes;        shot 6 1-spike-tests
open_mode live-activity; shot 4 2-live-activity-layouts
open_mode spikes-timer;  shot 5 3-spike-tests-timer-running
# Background the app: the real Live Activity shows in the Dynamic Island.
xcrun simctl launch "$udid" com.apple.Preferences
shot 4 4-live-activity-dynamic-island
