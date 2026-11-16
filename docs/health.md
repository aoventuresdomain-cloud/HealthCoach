# Weight trend and steps (board M2-04)

The smart scale writes to Apple Health; HealthCoach only reads. It asks once for read access to **body mass** and **step count** and never for write access. Nothing read from Health is stored by the app or sent anywhere: the numbers are worked out on the phone each time the app opens (project rule: no health data leaves the phone).

**Where.** `WeightTrend` and `StepsSummary` in CoachCore (`Health/BodyTrend.swift`, tested on Linux); the `HealthReading` protocol there is backed by `HealthKitReader` on the phone and `SampleHealthReader` in the simulator and UI tests. `BodyStats.shared` in the app holds the latest numbers for Today, Progress (M4-03) and the rules engine (M4-01).

**Weight trend.** A day with several weigh-ins counts once, at their mean. The 7-day average is the mean of the daily weights in the 7 days ending today, and needs at least 3 weigh-ins. It is compared with the 7 days before ("82.7 kg (7-day average), down 0.3 kg on last week"). Readings outside 30–250 kg are ignored as scale glitches.

**Steps.** Today's count so far, and the daily average over the previous 7 days that have any steps (a day with the phone off doesn't count as zero).

**When it reads.** On each app open after onboarding. A refusal or an error shows nothing and never blocks anything else.

**Entitlement.** `App/HealthCoach.entitlements` holds the HealthKit entitlement and `NSHealthShareUsageDescription` explains the read. CI builds with signing off, so the entitlement isn't applied there; the simulator uses sample data. Reading real scale data on the phone needs the paid account and is on the board's **Deferred to payment** list.

**Tests.** `BodyTrendTests` (CoachCore) and `LaunchFlagsUITests.testClockAndFixtureAreInjected` (`weight=82.7` from the sample data).
