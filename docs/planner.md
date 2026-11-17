# Week planner (board M2-01)

`WeekPlanner.plan(weekStarting:programme:profile:answers:dropping:calendar:)` in CoachCore turns the Sunday prompt (`WeekAnswers`: office days, early starts, late finishes) into a `WeekPlan`: each day's session slot, alarm, leave time and the lights-out before it.

**Days.** Monday to Friday are work days: office if the prompt says so, otherwise home. Saturday and Sunday are days off. The programme's schedule decides which session falls on which day.

**Morning first.** Wake = first commitment (an early start, or `workStart`) − commute (office days only) − shower − session − buffer. The session start is rounded down to 5 minutes. The morning fits if the alarm is no earlier than `earliestWake` (05:45).

**Evening otherwise.** The session starts at the finish (a late finish, or `workEnd`) plus the commute on office days, rounded up to 5 minutes. It fits if the session and shower end by `eveningEndBy` (20:30), which leaves time for dinner and wind-down. `trainingWindows` can rule out either slot.

**Neither fits.** The session moves to the nearest free day in the same week, preferring later days on a tie. It never moves to a `neverOn` day (Wednesday), a fixed-event day, or a day the programme bans for it (`notTheDayBefore`: no full body or second run on the day before basketball). If no day works, it is listed in `unplaced`, so Today can say so; it is never squeezed in.

**Days off.** A session starts at `dayOffSessionStart` (09:00) with the alarm 15 minutes before. A day off with no session has no alarm.

**Which days ring (E14).** Only a day with a fixed start gets an alarm: a session that sets one, or an office day. Home rest days, a home Wednesday (basketball is in the evening) and a day whose only plan is optional (the Sunday walk in weeks 1–3, `"alarm": false`) have none. The walk is still planned at `dayOffSessionStart`.

**Sleep.** Lights out the night before = alarm − `sleepHours` (7.5) − `fallAsleepMinutes` (15), and never later than `latestBedtime` (23:30). Wind-down is `windDownMinutes` before that. The night before a day with no alarm, lights out comes from the week's median alarm (E14), so bedtime stays close to the other nights.

**Reduced week.** Pass `Programme.droppedSessions(history:)` as `dropping`. Those sessions are left out, and their days become free for a move.

Defaults (requirements §2 and §12): commute 25 min, shower 15 min, buffer 15 min. All live in `Profile.schedule`, so onboarding and Settings can change them.

**Start week and passed sessions (E13).** `Profile.programme.startDate` is the paper start date (onboarding pre-fills Mon 16 Nov 2026 as a guess), so week = floor((day − start) / 7) + 1. Past the last week the plan holds at it (`PlannedDay.heldAtLastWeek`, a flag for the team, never shown) until the next phase's file exists. The planner is stateless, so it replays the week (QA-15). Given `now` and the session ids logged this week on any day (`completed`, from `SessionLog.sessionIDs(in:weekOf:)`), every unlogged session on an earlier day has passed, and today's has passed once its whole slot is over. Opening the app just after the alarm, or mid-session, never moves it. In day order, each passed session goes to this evening's normal slot (the end of the work day, or `workEnd` on a day off) if that slot isn't over and ends at least 2 h before tonight's wind-down. Otherwise it goes to the next session-free day later this week that its placement rules allow; otherwise it is dropped quietly (listed in `unplaced`, with no copy for the owner). The evening slot never follows the clock (QA-16): at 18:30 a session moved to 18:00 still shows 18:00, and once 18:00–18:45 is over unlogged it has passed again and moves on. Never before today, never two sessions in a day, never into next week. So Monday 21:00's move of Upper A to Friday is made again on Tuesday morning, and Friday's alarm survives every reconcile. The `-uitest` debug line shows `held=1` when the plan is holding at the last week (QA-17). Today, the alarm reconcile and the weather check all pass `now` and `completed`, so they agree.
