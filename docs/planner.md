# Week planner (board M2-01)

`WeekPlanner.plan(weekStarting:programme:profile:answers:dropping:calendar:)` in CoachCore turns the Sunday prompt (`WeekAnswers`: office days, early starts, late finishes) into a `WeekPlan`: each day's session slot, alarm, leave time and the lights-out before it.

**Days.** Monday to Friday are work days: office if the prompt says so, otherwise home. Saturday and Sunday are days off. The programme's schedule decides which session falls on which day.

**Morning first.** Wake = first commitment (an early start, or `workStart`) − commute (office days only) − shower − session − buffer. The session start is rounded down to 5 minutes. The morning fits if the alarm is no earlier than `earliestWake` (05:45).

**Evening otherwise.** The session starts at the finish (a late finish, or `workEnd`) plus the commute on office days, rounded up to 5 minutes. It fits if the session and shower end by `eveningEndBy` (20:30), which leaves time for dinner and wind-down. `trainingWindows` can rule out either slot.

**Neither fits.** The session moves to the nearest free day in the same week, preferring later days on a tie. It never moves to a `neverOn` day (Wednesday), a fixed-event day, or a day the programme bans for it (`notTheDayBefore`: no full body or second run on the day before basketball). If no day works, it is listed in `unplaced`, so Today can say so; it is never squeezed in.

**Days off.** A session starts at `dayOffSessionStart` (09:00) with the alarm 15 minutes before. A day off with no session has no alarm.

**Sleep.** Lights out the night before = alarm − `sleepHours` (7.5) − `fallAsleepMinutes` (15), and never later than `latestBedtime` (23:30). Wind-down is `windDownMinutes` before that.

**Reduced week.** Pass `Programme.droppedSessions(history:)` as `dropping`. Those sessions are left out, and their days become free for a move.

Defaults (requirements §2 and §12): commute 25 min, shower 15 min, buffer 15 min. All live in `Profile.schedule`, so onboarding and Settings can change them.
