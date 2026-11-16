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
# open_mode <mode> [more launch arguments]
open_mode() { xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true; m="$1"; shift; xcrun simctl launch "$udid" "$bundle" -screenshot "$m" "$@"; }
background() { xcrun simctl launch "$udid" com.apple.Preferences; }

open_mode spikes;        shot 6 1-spike-tests
open_mode live-activity; shot 4 2-live-activity-layouts
open_mode spikes-timer;  shot 5 3-spike-tests-timer-running
# Background the app: the real Live Activity shows in the Dynamic Island.
# Two shots 10 s apart prove it counts down while the app isn't on screen.
background;              shot 4 4-live-activity-dynamic-island
                         shot 10 4b-live-activity-dynamic-island-10s-later

# Finished: an 8 s rest runs out in the foreground (the app may be suspended
# in the background if the runner has no audio), then the island must be empty.
open_mode spikes-timer -restSeconds 8; shot 12 5-spike-tests-timer-finished
background;              shot 3 6-dynamic-island-empty-after-finish
# Cancelled: the app cancels by itself 5 s after starting.
open_mode spikes-timer-cancel; shot 9 7-spike-tests-timer-cancelled
background;              shot 3 8-dynamic-island-empty-after-cancel

# Alarms: the app taps "Set test alarms" by itself. A fresh simulator may show
# the AlarmKit permission prompt instead, which simctl can't answer: that
# screenshot is then the S1 finding, and the relaunch shows "All alarms set (0)".
open_mode spikes-set-alarms; shot 10 9-spike-tests-set-alarms
# Relaunch: the reconcile on open should show "All alarms set (14)".
open_mode spikes;        shot 8 10-spike-tests-relaunch
