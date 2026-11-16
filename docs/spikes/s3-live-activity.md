# S3 · Live Activity rest timer with voice cues (board M0-06)

Owner: iOS Interface Engineer. Run from **Spike tests → Start test timer** (M0-11) on the CEO's iPhone, via the Setup Desk (Part D3).

## How it works

- `RestTimerSpike` starts a Live Activity (`RestTimerAttributes`) whose end time is fixed at start. The widget draws the countdown with `Text(timerInterval:countsDown:)`, so the lock screen and Dynamic Island keep counting with no updates from the app.
- `VoiceCuePlayer` keeps the audio session active with a silent loop while the timer runs (`UIBackgroundModes = audio`), so iOS doesn't suspend the app when the phone locks. It mixes with music until 3.5 s before the end, then ducks others for "3, 2, 1, go" (en-GB voice), then deactivates with `notifyOthersOnDeactivation` so music comes back up.
- At zero, or on Cancel, the activity is ended with `.immediate` dismissal. On opening the screen, any leftover rest activity (app killed mid-rest) is ended. `staleDate` is the end time as a backstop.

## Test steps (about 3 minutes)

1. Headphones in, music playing from another app.
2. Open HealthCoach → Spike tests → Start test timer.
3. Lock the phone. Check the lock screen countdown; long-press/swipe to see the Dynamic Island.
4. Wait 90 s. Listen for "3, 2, 1, go" over quieter music.
5. Check the lock screen: the timer should be gone and the music back at full volume.
6. Repeat, tapping Cancel mid-rest: lock screen clears at once.

## Simulator screenshots (for CI, board M0-12)

The app takes a `-screenshot <mode>` launch argument and opens straight on that state, no taps:

| Mode | Shows |
|---|---|
| `spikes` | Spike tests screen, nothing run |
| `spikes-timer` | Spike tests screen with the 90 s timer running (starts a real Live Activity) |
| `live-activity` | The lock-screen and Dynamic Island layouts drawn in-app, counting down (same views as the widget) |

```sh
APP=com.aoventures.healthcoach
xcrun simctl launch booted $APP -screenshot spikes;        sleep 3; xcrun simctl io booted screenshot spikes.png
xcrun simctl terminate booted $APP
xcrun simctl launch booted $APP -screenshot live-activity; sleep 3; xcrun simctl io booted screenshot live-activity-layouts.png
xcrun simctl terminate booted $APP
xcrun simctl launch booted $APP -screenshot spikes-timer;  sleep 5; xcrun simctl io booted screenshot spikes-timer.png
# Background the app: the real Live Activity shows in the Dynamic Island (use an iPhone Pro simulator).
xcrun simctl launch booted com.apple.Preferences;          sleep 3; xcrun simctl io booted screenshot dynamic-island.png
```

`simctl` can't lock the simulator, so the lock-screen view comes from `live-activity-layouts.png`; the real lock screen is checked on the phone in M0b.

## Results

| Check | Result | Notes |
|---|---|---|
| Countdown on lock screen while locked | _pending_ | |
| Countdown in Dynamic Island | _pending_ | |
| Voice cues heard through headphones while locked | _pending_ | |
| Music ducks, not stops, and comes back | _pending_ | |
| Activity gone after finish | _pending_ | |
| Activity gone after cancel | _pending_ | |

## Limits and risks

- Background audio keep-alive is the standard route for workout apps, but App Review may question it; we ship only via TestFlight, where it is accepted. If it ever fails, fallback: a time-sensitive local notification at zero with a short spoken-cue sound file (no countdown cues while locked).
- Live Activities can be switched off per app in Settings; the screen says so if they are.
- Not yet compiled: cloud sessions have no Swift toolchain (board M0-09), so the first build is Xcode Cloud's.
