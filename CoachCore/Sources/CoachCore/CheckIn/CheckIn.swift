import Foundation

/// Board N1: the weekly check-in (Advisor A1). Three one-tap answers,
/// defaulting to Good, Fine and None. Only the scale moves calories: no
/// answer here ever does.
public struct CheckIn: Codable, Sendable, Equatable {
    public var date: Date
    public var energy: Energy = .good
    public var sleep: Sleep = .fine
    /// Where it hurts; empty is "None".
    public var pain: [PainArea] = []

    public init(date: Date, energy: Energy = .good, sleep: Sleep = .fine, pain: [PainArea] = []) {
        self.date = date
        self.energy = energy
        self.sleep = sleep
        self.pain = pain
    }

    public enum Energy: String, Codable, Sendable, CaseIterable { case good, ok, low }
    public enum Sleep: String, Codable, Sendable, CaseIterable { case good, fine, poor }

    /// Low energy and poor sleep together: one low-recovery signal for the
    /// drop-to-2 rule (R2), as a "Sore" session answer is. Either alone goes
    /// to the Claude summary only.
    public var isLowRecovery: Bool { energy == .low && sleep == .poor }

    public var hasPain: Bool { !pain.isEmpty }
}

/// The areas the pain question offers (Advisor A1).
public enum PainArea: String, Codable, Sendable, CaseIterable {
    case shoulder, elbow, wrist, back, knee, other
}

extension CheckIn {
    /// How long a pain answer swaps exercises out.
    public static let painSwapDays = 7

    /// The check-in due on `date`: the profile's check-in day, from its time.
    public static func isDue(on date: Date, profile: Profile, last: CheckIn?, calendar: Calendar = .current) -> Bool {
        guard profile.programme.startDate != nil,
              Weekday(calendarWeekday: calendar.component(.weekday, from: date)) == profile.coach.checkInDay else { return false }
        let time = profile.coach.checkInTime
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        guard minutes >= time.minutesSinceMidnight else { return false }
        return !(last.map { calendar.isDate($0.date, inSameDayAs: date) } ?? false)
    }

    /// The pain areas in force on `date`: those from any check-in in the
    /// 7 days up to it (a check-in with no pain doesn't clear an earlier one early).
    public static func painAreas(_ checkIns: [CheckIn], on date: Date, calendar: Calendar = .current) -> Set<PainArea> {
        let day = calendar.startOfDay(for: date)
        var areas = Set<PainArea>()
        for checkIn in checkIns {
            let from = calendar.startOfDay(for: checkIn.date)
            guard let until = calendar.date(byAdding: .day, value: painSwapDays, to: from),
                  from <= day, day < until else { continue }
            areas.formUnion(checkIn.pain)
        }
        return areas
    }

    /// Advisor condition (d): the areas answered "Yes" in both of the last
    /// two check-ins up to `date` ("other" included). Information for the
    /// summary only: no prompt, no tap.
    public static func stillSore(_ checkIns: [CheckIn], asOf date: Date) -> Set<PainArea> {
        let recent = checkIns.filter { $0.date <= date }.sorted { $0.date < $1.date }.suffix(2)
        guard recent.count == 2, let first = recent.first, let second = recent.last else { return [] }
        return Set(first.pain).intersection(second.pain)
    }

    /// The summary line for `stillSore`, word for word as the Advisor set it.
    public static let stillSoreLine = "Still sore after 2 weeks: worth seeing a GP or physio."
}

/// What the check-in screen opens with, already filled in.
public struct CheckInPrefill: Sendable, Equatable {
    public let weightAverageKg: Double?
    public let weightChangeKg: Double?
    public let sessionsDone: Int
    public let sessionsPlanned: Int
    public let averageSteps: Int?

    /// For the 7 days before `now` (the week the check-in closes).
    public static func make(now: Date, programme: Programme, profile: Profile, history: [SessionLog],
                            weights: [WeightSample], steps: [StepCount],
                            calendar: Calendar = .current) -> CheckInPrefill {
        let today = calendar.startOfDay(for: now)
        let from = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let trend = WeightTrend.make(samples: weights, endingOn: now, calendar: calendar)
        let planned = profile.programme.startDate.map {
            CoachSummary.plannedSessions(programme: programme, start: $0, from: from, to: now, calendar: calendar)
        } ?? 0
        let done = Set(history.filter { $0.startedAt >= from && $0.startedAt <= now && $0.isComplete }
            .map { "\(calendar.startOfDay(for: $0.startedAt).timeIntervalSince1970)|\($0.sessionID)" }).count
        return CheckInPrefill(weightAverageKg: trend?.averageKg, weightChangeKg: trend?.changeKg,
                              sessionsDone: done, sessionsPlanned: planned,
                              averageSteps: StepsSummary.make(days: steps, today: now, calendar: calendar).sevenDayAverage)
    }
}

/// N1: exercises out for a pain area, and what replaces each.
public enum PainSwaps {
    public struct Swap: Sendable, Equatable {
        /// The replacement, or nil: left out while the pain lasts.
        public let to: String?
        /// The replacement takes dumbbells.
        public let loaded: Bool

        /// `original`'s place in the session, done as `to`: same sets, reps or
        /// seconds and effort. A loaded swap starts from the original's weight
        /// until it has its own history; an unloaded one moves by reps.
        func item(replacing original: StrengthItem) -> StrengthItem? {
            guard let to else { return nil }
            let reps = original.reps ?? (original.seconds == nil ? IntRange(min: 8, max: 12) : nil)
            let startKg = loaded ? original.startKg : nil
            let progression: Progression = original.seconds != nil ? .time : (startKg == nil ? .reps : .double)
            return StrengthItem(exercise: to, sets: original.sets, repsInReserve: original.repsInReserve,
                                reps: reps, seconds: original.seconds, perSide: original.perSide, startKg: startKg,
                                tempo: original.tempo, progression: progression, note: nil, graduate: nil, autoSwap: nil)
        }
    }

    /// How many `swap` steps the chain may take (Advisor condition a).
    public static let maxChainSteps = 5

    /// For each exercise in `exercises` that loads one of `areas` ("other"
    /// never swaps anything, condition d), the first exercise along its `swap`
    /// chain that loads none of them. The chain stops at its first repeat or
    /// after `maxChainSteps` steps (condition a); nil `to` then, and the
    /// exercise is dropped, never replaced (condition b).
    public static func make(areas: Set<PainArea>, exercises: [String],
                            catalogue: ExerciseCatalogue) -> [String: Swap] {
        let areas = areas.subtracting([.other])
        guard !areas.isEmpty else { return [:] }
        func loads(_ id: String) -> Bool {
            !Set(catalogue.exercise(id)?.loads ?? []).isDisjoint(with: areas)
        }
        var out: [String: Swap] = [:]
        for id in exercises where loads(id) {
            var seen: Set<String> = [id]
            var next = catalogue.exercise(id)?.swap
            var safe: String?
            var steps = 0
            while let candidate = next, steps < maxChainSteps, seen.insert(candidate).inserted {
                steps += 1
                if !loads(candidate) { safe = candidate; break }
                next = catalogue.exercise(candidate)?.swap
            }
            let loaded = safe.flatMap { catalogue.exercise($0)?.equipment.contains(.dumbbells) } ?? false
            out[id] = Swap(to: safe, loaded: loaded)
        }
        return out
    }

    /// Advisor condition (c): knee or back pain turns the run-walk into a
    /// brisk walk for the 7 days.
    public static func walksInsteadOfRunning(_ areas: Set<PainArea>) -> Bool {
        !areas.isDisjoint(with: [.knee, .back])
    }

    /// The one What-changed line for the run-walk, or nil when it runs as planned.
    public static func runWalkLine(areas: Set<PainArea>, minutes: Int) -> String? {
        guard walksInsteadOfRunning(areas) else { return nil }
        let sore = [PainArea.knee, .back].filter(areas.contains).map(\.rawValue).joined(separator: " and ")
        return "Run-walk is a brisk \(minutes)-minute walk this week: easier on the \(sore)."
    }

    /// Every strength exercise in `programme`, for `make`.
    public static func exercises(in programme: Programme) -> [String] {
        programme.strengthItems.map(\.exercise)
    }
}
