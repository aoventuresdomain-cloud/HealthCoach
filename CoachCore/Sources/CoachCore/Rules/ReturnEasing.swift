import Foundation

// Board N8: easing back in after a break (Advisor A2, 18 Nov). Counted as
// days since the last strength session:
// - 10–20 days: first session at 90% of last loads, rounded down to the
//   dumbbell step; back to previous loads within 2 sessions per exercise.
// - 21–42 days: 80%, one extra rep in reserve for the first week, rebuilt
//   over 3 sessions.
// - Over 42 days: the current phase's week 1 effort at 70%, flagged in the
//   Claude summary.
// - Runs: 10+ days off repeats the previous week's run; 21+ drops back two weeks.
// Nothing is asked. Like the rest of the coach this is replayed from the
// logs: the eased sessions are left out of progression, so the session that
// completes the rebuild is the one from before the break, and progression
// carries on from there as if the break hadn't happened.

/// A break from strength work, and how the loads come back from it.
public struct ReturnEasing: Sendable, Equatable {
    public enum Band: Sendable, Equatable {
        /// 10–20 days off.
        case short
        /// 21–42 days off.
        case long
        /// Over 42 days off: start the phase's week 1 effort again.
        case restart
    }

    /// Whole days from the last strength session before the break to the first after it.
    public let daysOff: Int
    public let band: Band
    /// The day of the first session after the break.
    public let firstSessionDay: Date

    public static let minimumDaysOff = 10

    public init?(daysOff: Int, firstSessionDay: Date) {
        switch daysOff {
        case ..<Self.minimumDaysOff: return nil
        case ...20: band = .short
        case ...42: band = .long
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
    /// 70%: the 4th, in three equal steps (our reading of A2; the Advisor may change it).
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

    /// The summary's line.
    var summaryLine: String {
        let percent = Int((startFraction * 100).rounded())
        let restart = band == .restart ? ", from week 1 effort" : ""
        return "- Back after \(daysOff) days off: easing in at \(percent)% of last loads\(restart), back to them by session \(fullAtSession)"
    }
}

extension Programme {
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

    /// The break the session on `date` is easing back from, if the rebuild
    /// isn't over (fewer than `fullAtSession − 1` strength sessions logged
    /// since). For the player's line and the summary.
    public func easing(history: [SessionLog], on date: Date, calendar: Calendar = .current) -> ReturnEasing? {
        guard let latest = strengthBreaks(history: history, before: date, calendar: calendar).last else { return nil }
        let since = strengthLogs(history, before: date).filter { $0.startedAt >= latest.firstSessionDay }.count
        return since < latest.fullAtSession - 1 ? latest : nil
    }

    /// The eased prescription for `item` on `date`, or the normal one. Eased
    /// sessions' sets for this exercise are left out of the replay, so the
    /// rebuild returns to the pre-break state.
    func easedPrescription(for item: StrengthItem, week: Int, history: [SessionLog],
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
            for log in after.prefix(brk.fullAtSession - 1) { eased.insert(log.id) }
            if index == breaks.count - 1 {
                current = brk
                session = after.count + 1
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

    /// The week of the run-walk to do on `date`: the previous week's after 10
    /// or more days without a run, two weeks back after 21 or more.
    public func runWeek(_ week: Int, history: [SessionLog], on date: Date, calendar: Calendar = .current) -> Int {
        let runs = history.filter { log in
            guard log.startedAt < date, case .runWalk = sessions[log.sessionID] else { return false }
            return true
        }
        guard let last = runs.map(\.startedAt).max() else { return week }
        let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: last),
                                          to: calendar.startOfDay(for: date)).day ?? 0
        if gap >= 21 { return max(1, week - 2) }
        if gap >= ReturnEasing.minimumDaysOff { return max(1, week - 1) }
        return week
    }

    func strengthLogs(_ history: [SessionLog], before date: Date) -> [SessionLog] {
        history.filter { log in
            guard log.startedAt < date, case .strength = sessions[log.sessionID] else { return false }
            return true
        }.sorted { $0.startedAt < $1.startedAt }
    }
}
