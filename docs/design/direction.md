# Design direction · HealthCoach UI

Product Designer · 17 Nov 2026 · Builds on [`m1/README.md`](m1/README.md) (still in force). The ranked change list for the 18 Nov build is [`ui-pass-1.md`](ui-pass-1.md).

**The feel: easy to use and cool.** Easy means the next action is the biggest thing on screen and nothing asks a question. Cool means it feels like a piece of kit: dark, big rounded numbers, colour that tells you the state, and a small physical response (motion plus haptic) every time you press something. Never cool at the cost of easy.

**Guiding rule:** if it takes thinking or admin time, it has failed. In normal use the only taps are **Start, Next and Done**.

## What current iOS 26 practice says, and what we take from it

| Practice | What we do |
|---|---|
| **Liquid Glass is for the control layer, not content** (Apple HIG, iOS 26). Glass floats over content; never glass on glass; content cards stay solid. | Glass on chrome only: the tab bar (automatic), ✕ buttons, small secondary buttons. Cards, numbers and the green primary button stay solid, because they must read at arm's length mid-set. |
| **System components first.** Standard `TabView`, sheets and toolbars pick up glass, minimise-on-scroll and accessibility for free. | One `TabView` (Today, Meals, Progress). No custom tab bar or nav chrome. |
| **One-handed, thumb zone.** Primary actions at the bottom; 44 pt minimum target, bigger when sweaty. | Kept: one 76 pt primary at the bottom, at most one 50 pt secondary above it, ✕ top-left out of reach. Nothing under 44 pt in the bottom half. |
| **Glanceable at a distance.** Fitness apps lead with one huge number and use colour as state. | One hero number per screen; colour = state (green go, blue rest/walk, orange needs you). The run-walk screen is washed in its interval colour. |
| **Haptics confirm, never decorate.** `sensoryFeedback` tied to real events. | Every press of Done/Next, each counted rep, the last 3 s of rest and each run-walk change gets one haptic (table below). |
| **Motion explains change.** Numbers roll, they don't jump; short spring animations; honour Reduce Motion. | `numericText` content transitions on every live number; `.snappy` springs; Start zooms into the player. Reduce Motion drops to fades. |
| **Lock screen and Live Activity are the real workout UI** when the phone is on the bench. | Lock screen shows the countdown, a progress bar and **the weight to dial**, large, in green. |
| **Dark, OLED-true, with semantic colours.** | Dark everywhere (not just the player). Semantic system colours, so light mode still works if switched on. |
| **Accessibility:** Dynamic Type, VoiceOver, 4.5:1 contrast, Reduce Transparency. | Text scales; workout screens cap at `accessibility2` to keep "no scrolling mid-set". Black text on green (white fails contrast). Glass falls back automatically under Reduce Transparency. |

## Tokens

Add as `App/Design/Theme.swift`; use these names instead of literals in new and touched code.

```swift
import SwiftUI

enum Space {            // 4-pt grid
    static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12
    static let l: CGFloat = 16   // screen gutter, gap between cards
    static let xl: CGFloat = 20  // card padding
    static let xxl: CGFloat = 24
}

enum Radius {
    static let card: CGFloat = 20, primary: CGFloat = 22, secondary: CGFloat = 16, pill: CGFloat = 14
}

extension Color {
    static let go = Color.green          // primary, jog, progress, loads going up
    static let rest = Color.blue         // rest, walk
    static let caution = Color.orange    // warnings, Guess, Fix
    static let onGo = Color.black        // text on green (white fails 4.5:1)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let canvas = Color(.systemGroupedBackground)
}

extension Font {
    /// Big live numbers: rounded, bold, fixed-width digits so they don't jitter.
    static func coachNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }
    /// Small caps-style labels above numbers ("REST", "DIAL TO").
    static let coachLabel = Font.footnote.weight(.semibold)
}

extension Animation {
    static let coach = Animation.snappy(duration: 0.3)
}
```

**Colour.** Canvas black, cards `surface`, one accent: `go` green (also the asset-catalogue `AccentColor`). Blue only for rest and walk. Orange only when the owner should look. No other hues, no gradients except the rest ring.

**Type.** SF Pro for words, **SF Pro Rounded for live numbers** (`coachNumber`). Sizes in use: 112 run-walk clock, 88 run-walk label, 76 rest clock, 56 rep counter, 52 dial-to weight, 48 set/reps/kg. Words: `.largeTitle.bold()` screen title, `.title2.bold()` card title, `.body`, `coachLabel` uppercase secondary.

**Spacing.** 16 pt gutters and gaps, 20 pt card padding, 20 pt card radius, 22 pt primary-button radius.

**Motion.** `.coach` spring for state changes; `.contentTransition(.numericText(countsDown:))` on every live number; nothing longer than 0.4 s; with Reduce Motion, use opacity only.

**Haptics** (`.sensoryFeedback`, all one-shot):

| Event | Feedback |
|---|---|
| Done / Next / Start | `.impact(weight: .medium)` |
| Rep counter tap | `.increase` |
| Last 3 s of rest (each second) | `.impact(weight: .light)` |
| Rest ends, next set starts | `.impact(weight: .heavy)` |
| Run-walk interval changes | `.impact(weight: .heavy)` |
| Session done | `.success` |
| Zero-alarms warning appears | `.warning` (not on the "alarms were missing, now set" banner: that's reassurance) |

## Component rules

- **Primary button:** full width, 76 pt, solid `go`, `onGo` text, bottom. One per screen. Medium impact haptic.
- **Secondary button:** 50 pt, `.buttonStyle(.glass)`, directly above the primary. Optional by definition.
- **Close (✕):** 44 pt circle, `.buttonStyle(.glass)`, top-left, always asks before ending.
- **Card:** `surface`, radius 20, padding 20. Solid, never glass.
- **Hero number:** one per screen, `coachNumber`, rolls with `numericText`.
- **Meta line:** session facts as one secondary line ("39 min · 9 exercises · Dumbbells, bench, bar"), not chips.
- **Pre-filled choice:** default already selected, 44 pt+ tall, ignoring it is the answer.
- **Banner:** orange tint card, one bold clause plus one plain clause, `.warning` haptic once.

## Screen rules

- **Today:** title = next action and time. One session card, one timeline. Meals for today appear as timeline rows (breakfast, lunch order, dinner), so the Meals tab is never needed on a normal day (Advisor condition). The Sunday prompt is a card on Today at the weekend, not a tab.
- **Workout player:** unchanged structure (M1 rules). Add rounded numbers, rolling counter, haptics, a rest ring that stays blue and turns green only for the last 3 s (at 10 s the "Dial to" weight pulses instead), celebratory done header.
- **Run-walk:** full-screen wash of the interval colour (12 % opacity) so the state reads from across the room; heavy haptic on every change.
- **Sunday prompt:** five day pills, pre-filled from last week, `Done`. Early/late times stay folded away.
- **Meals:** today's meals pre-ticked; one tap unticks, and unticking triggers nothing (no prompt, no red). Top-up list grouped by aisle with 44 pt tick targets. Lunch card on office days shows one order, large; "Another" is the secondary.
- **Progress:** one hero chart (Swift Charts) whose big number and line are the 7-day average; daily weigh-ins are faint dots, never the big number. Phase line reads "Phase 1 · week 3 of 6" with a quieter "Week 3 of about 20" under it, so 6 never reads as a finish line. Lifts table with next loads: green ↑ when going up; held or reduced loads neutral grey, never red, never a down arrow. Photo card only when due. No streaks, badges or missed-session copy anywhere.

## Open taste decisions (for the Gate 2 pack, not asked)

1. Accent colour: system green (default) or one brand colour.
2. Always dark (default) or follow the system.
3. App icon (placeholder until Gate 2).
4. Rounded numerals (default) or standard SF Pro.

Sources: Apple HIG "Materials" and "Adopting Liquid Glass" (iOS 26); [Liquid Glass in SwiftUI practical reference](https://medium.com/@veersr9/ios-26-liquid-glass-in-swiftui-a-practical-reference-demo-app-liquidglassreference-69b8d46dc055); [Liquid Glass official best practices summary](https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo).
