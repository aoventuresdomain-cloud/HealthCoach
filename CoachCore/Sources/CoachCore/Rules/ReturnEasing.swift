import Foundation

// Board N8: easing back in after a break (Advisor A2, 18 Nov). Counted as
// days since the last strength session:
// - 10–20 days: first session at 90% of last loads, rounded down to the
//   dumbbell step; back to previous loads at the 2nd session per exercise.
// - 21–41 days: 80%, one extra rep in reserve for the first week, back at the 3rd.
// - 42 days or more: the current phase's week 1 effort at 70%, then 80, 90
//   and back at the 4th; flagged in the Claude summary.
// - Steps of about 10% a session, each rounded down to the dumbbell step. A
//   session answered Sore holds the step rather than moving on (Advisor, 18 Nov).
// - Runs keep their own clock (days since the last run): 10+ days repeats the
//   last week run, 21+ goes back one week, 42+ two, never before week 1.
// Nothing is asked. Like the rest of the coach this is replayed from the
// logs: the eased sessions are left out of progression, so the session that
// completes the rebuild is the one from before the break, and progression
// carries on from there as if the break hadn't happened.

/// A break from strength work, and how the loads come back from it.
public struct ReturnEasing: Sendable, Equatable {
    public enum Band: Sendable, Equatable {
        /// 10–20 days off.
        case short
        /// 21–41 days off.
        case long
        /// 42 days or more off: start the phase's week 1 effort again.
        case restart
    }

    /// Whole days from the last strength session before the break to the first after it.
    public let daysOff: Int
    public let band: Band
    /// The day of the first session after the break.
    public let firstSessionDay: Date

    public static let minimumDaysOff = 10
    public static let longDaysOff = 21
    public static let restartDaysOff = 42

    public init?(daysOff: Int, firstSessionDay: Date) {
        switch daysOff {
        case ..<Self.minimumDaysOff: return nil
        case ...20: band = .short
        case ..<Self.restartDaysOff: band = .long
        default: band = .restart
        }
        self.daysOff = daysOff
        self.firstSessionDay = firstSessionDay
    }

    /// The share of the last loads for the first session.
    public var startFraction: Double {
        switch band {
        case .short: 0.9
        case .long: 0.8
        case .restart: 0.7
        }
    }

    /// The session per exercise (1-based) that is back at the previous load.
    /// 90%: the 2nd ("within 2 sessions"); 80%: the 3rd ("over 3 sessions");
    /// 70%: the 4th, via 80 and 90 (Advisor, 18 Nov).
    public var fullAtSession: Int {
        switch band {
        case .short: 2
        case .long: 3
        case .restart: 4
        }
    }

    /// The share of the last loads at the exercise's `session`-th session
    /// after the break; 1 from `fullAtSession` on.
    public func fraction(atSession session: Int) -> Double {
        guard session < fullAtSession else { return 1 }
        let steps = Double(fullAtSession - 1)
        return startFraction + (1 - startFraction) * Double(session - 1) / steps
    }

    /// One extra rep in reserve in the first week back, for 21–42 days off.
    public func extraRepInReserve(on date: Date, calendar: Calendar) -> Bool {
        guard band == .long else { return false }
        let days = calendar.dateComponents([.day], from: firstSessionDay, to: calendar.startOfDay(for: date)).day ?? 0
        return days < 7
    }

    /// The player's one line.
    public var line: String { "Easing back in after \(daysOff) days off" }

    /// Today's one line for the next session ("Easing back in: 80% today").
    public func todayLine(atSession session: Int) -> String {
        "Easing back in: \(Int((fraction(atSession: session) * 100).rounded()))% today"
    }

    /// Where the rebuild stands after `logs` (sessions since the break, oldest
    /// first): the next session's step, and the logs that were eased. A
    /// session answered Sore holds the step for the next one, and so does one
    /// done while a check-in pain answer is in force (N1, `holds`).
    func rebuild(after logs: [SessionLog],
                 holds: (SessionLog) -> Bool = { _ in false }) -> (next: Int, eased: [SessionLog]) {
        var step = 1
        var eased: [SessionLog] = []
        for log in logs where step < fullAtSession {
            eased.append(log)
            if log.recovery != .sore && !holds(log) { step += 1 }
        }
        return (step, eased)
    }

    /// The summary's line.
    var summaryLine: String {
        let percent = Int((startFraction * 100).rounded())
        let restart = band == .restart ? ", from week 1 effort" : ""
        return "- Back after \(daysOff) days off: easing in at \(percent)% of last loads\(restart), back to them by session \(fullAtSession)"
    }
}

extension Programme {
    /// N1: a session done while a check-in pain answer (any area but "other")
    /// is in force holds the easing step, as a Sore answer does.
    static func painHolds(_ checkIns: [CheckIn], calendar: Calendar) -> (SessionLog) -> Bool {
        guard !checkIns.isEmpty else { return { _ in false } }
        return { log in
            !CheckIn.painAreas(checkIns, on: log.startedAt, calendar: calendar).subtracting([.other]).isEmpty
        }
    }

    /// Every strength break of 10 days or more in `history` before `date`,
    /// oldest first. A break still running on `date` counts, ending on `date`.
    func strengthBreaks(history: [SessionLog], before date: Date, calendar: Calendar) -> [ReturnEasing] {
        let days = strengthLogs(history, before: date).map { calendar.startOfDay(for: $0.startedAt) }
        guard !days.isEmpty else { return [] }
        let ends = days.dropFirst() + [calendar.startOfDay(for: date)]
        return zip(days, ends).compactMap { from, to in
            let gap = calendar.dateComponents([.day], from: from, to: to).day ?? 0
            return ReturnEasing(daysOff: gap, firstSessionDay: to)
        }
    }

    /// The break the session on `date` is easing back from while the rebuild
    /// isn't over, counted in strength sessions since. For the player's line,
    /// Today's line (`todayLine`) and the summary.
    public func easing(history: [SessionLog], checkIns: [CheckIn] = [], on date: Date,
                       calendar: Calendar = .current) -> ReturnEasing? {
        easingStep(history: history, checkIns: checkIns, on: date, calendar: calendar)?.easing
    }

    /// The break and the next session's step (1-based), while rebuilding.
    public func easingStep(history: [SessionLog], checkIns: [CheckIn] = [], on date: Date,
                           calendar: Calendar = .current) -> (easing: ReturnEasing, session: Int)? {
        guard let latest = strengthBreaks(history: history, before: date, calendar: calendar).last else { return nil }
        let since = strengthLogs(history, before: date).filter { $0.startedAt >= latest.firstSessionDay }
        let next = latest.rebuild(after: since, holds: Self.painHolds(checkIns, calendar: calendar)).next
        return next < latest.fullAtSession ? (latest, next) : nil
    }

    /// The eased prescription for `item` on `date`, or the normal one. Eased
    /// sessions' sets for this exercise are left out of the replay, so the
    /// rebuild returns to the pre-break state.
    func easedPrescription(for item: StrengthItem, week: Int, history: [SessionLog], checkIns: [CheckIn] = [],
                           on date: Date, calendar: Calendar) -> Prescription? {
        let breaks = strengthBreaks(history: history, before: date, calendar: calendar)
        guard !breaks.isEmpty else { return prescription(for: item, week: week, history: history) }
        let logs = strengthLogs(history, before: date)

        // Which logged sessions of this exercise were eased, and where the latest rebuild stands.
        var eased = Set<UUID>()
        var session = 0
        var current: ReturnEasing?
        for (index, brk) in breaks.enumerated() {
            let next = index + 1 < breaks.count ? breaks[index + 1].firstSessionDay : .distantFuture
            let after = logs.filter { log in
                log.startedAt >= brk.firstSessionDay && log.startedAt < next
                    && log.sets.contains { $0.exercise == item.exercise || $0.exercise == item.graduate?.to }
            }
            let rebuilt = brk.rebuild(after: after, holds: Self.painHolds(checkIns, calendar: calendar))
            for log in rebuilt.eased { eased.insert(log.id) }
            if index == breaks.count - 1 {
                current = brk
                session = rebuilt.next
            }
        }
        let replay = history.map { log -> SessionLog in
            guard eased.contains(log.id) else { return log }
            var copy = log
            copy.sets.removeAll { $0.exercise == item.exercise || $0.exercise == item.graduate?.to }
            return copy
        }
        guard let base = prescription(for: item, week: week, history: replay) else { return nil }
        guard let current, session < current.fullAtSession else { return base }

        let fraction = current.fraction(atSession: session)
        let kg = base.kg.map { kg in max(loadStepKg, (kg * fraction / loadStepKg + 1e-9).rounded(.down) * loadStepKg) }
        var sets = base.sets
        var reserve = base.repsInReserve
        if current.band == .restart, let first = prescription(for: item, week: 1, history: replay) {
            sets = first.sets
            reserve = first.repsInReserve
        }
        if current.extraRepInReserve(on: date, calendar: calendar) { reserve += 1 }
        return Prescription(
            exercise: base.exercise, sets: sets, repsInReserve: reserve, reps: base.reps, seconds: base.seconds,
            range: base.range, kg: kg, slowTempo: base.slowTempo,
            atDumbbellLimit: base.atDumbbellLimit && kg == base.kg, step: .easing)
    }

    /// The week of the run-walk to do on `date`, on the runs' own clock
    /// (Advisor, 18 Nov): after 10+ days without a run, repeat the last week
    /// run; 21+ days, one week before it; 42+, two. Never before week 1, and
    /// never past `week`.
    public func runWeek(_ week: Int, history: [SessionLog], on date: Date, calendar: Calendar = .current) -> Int {
        let runs = history.filter { log in
            guard log.startedAt < date, case .runWalk = sessions[log.sessionID] else { return false }
            return true
        }
        guard let last = runs.max(by: { $0.startedAt < $1.startedAt }) else { return week }
        let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: last.startedAt),
                                          to: calendar.startOfDay(for: date)).day ?? 0
        let back = switch gap {
        case ReturnEasing.restartDaysOff...: 2
        case ReturnEasing.longDaysOff...: 1
        case ReturnEasing.minimumDaysOff...: 0
        default: -1
        }
        guard back >= 0 else { return week }
        return min(week, max(1, last.week - back))
    }

    func strengthLogs(_ history: [SessionLog], before date: Date) -> [SessionLog] {
        history.filter { log in
            guard log.startedAt < date, case .strength = sessions[log.sessionID] else { return false }
            return true
        }.sorted { $0.startedAt < $1.startedAt }
    }
}
