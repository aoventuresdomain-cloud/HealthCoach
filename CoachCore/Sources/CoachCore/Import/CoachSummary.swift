import Foundation

// Board M4-02: the summary the owner shares with Claude in one tap ("Ask the
// coach now", a stall flag or a checkpoint). It ends with the exact reply
// format, so Claude's answer can be imported. It carries only what the coach
// needs: no name, no photos, no raw daily Health data (project rule).

public enum CoachSummary {
    /// Why the summary is being sent.
    public enum Reason: Sendable, Equatable {
        case askNow
        case flag(CoachFlag)

        var title: String {
            switch self {
            case .askNow: "Check-in"
            case let .flag(.checkpoint(n)): "Checkpoint \(n)"
            case let .flag(flag): "Stall flag: " + flag.line
            }
        }
    }

    /// The text to share. `reason` nil picks the first flag, or "Check-in".
    /// Nil before onboarding sets a start date.
    public static func text(reason: Reason? = nil, programme: Programme, profile: Profile,
                            history: [SessionLog], weights: [WeightSample], steps: [StepCount] = [],
                            meals: MealAdherence? = nil, waist: WaistLog? = nil,
                            blocks: [CoachBlock], socialMeals: [Date] = [], now: Date,
                            calendar: Calendar = .current) -> String? {
        guard let start = profile.programme.startDate,
              let review = CoachReview.make(programme: programme, profile: profile, history: history,
                                            weights: weights, blocks: blocks, now: now, calendar: calendar)
        else { return nil }
        let reason = reason ?? review.flags.first.map(Reason.flag) ?? .askNow
        let programmeWeek = programme.plannedDay(on: now, start: start, calendar: calendar).week

        var lines: [String] = []
        lines.append("HealthCoach · \(reason.title)")
        lines.append("\(CoachText.day(now, calendar: calendar)) · \(programme.name), week \(programmeWeek ?? review.week) of \(programme.weeks) (week \(review.week) overall)")
        var about = "Goal: lean, strong and defined over 16–20 weeks."
        if let height = profile.about.heightCm { about += " \(CoachText.number(height)) cm." }
        if let weight = profile.about.weightKg { about += " Started at \(CoachText.kg(weight))." }
        lines.append(about)
        lines.append("Kit: dumbbells to \(CoachText.kg(programme.dumbbellLimitKg)) (\(CoachText.kg(programme.loadStepKg)) steps), bench, pull-up bar. Basketball every Wednesday.")
        lines.append("")

        lines.append("Body")
        if let trend = WeightTrend.make(samples: weights, endingOn: now, calendar: calendar) {
            lines.append("- Weight: \(trend.summary) (\(trend.daysWeighed) of 7 days weighed)")
        } else {
            lines.append("- Weight: not enough weigh-ins this week")
        }
        if let rate = CalorieRules.lossRate(samples: weights, endingOn: now, calendar: calendar) {
            let word = rate >= 0 ? "losing" : "gaining"
            lines.append("- 2-week rate: \(word) \(CoachText.kg(abs(rate))) a week (aim \(range(CalorieRules.lossRate(phase: programme.phase).target)) kg)")
        }
        let stepSummary = StepsSummary.make(days: steps, today: now, calendar: calendar)
        if let average = stepSummary.sevenDayAverage {
            lines.append("- Steps: \(CoachText.thousands(average)) a day (7-day average)")
        }
        // N7: waist only at a checkpoint (Advisor A3: it stays on the phone otherwise).
        if case .flag(.checkpoint) = reason, let line = waist?.summaryLine(calendar: calendar) {
            lines.append(line)
        }
        lines.append("")

        lines.append("Food")
        lines.append("- Target: \(review.calories.summary) (\(reasonText(review.calories.reason)))")
        if let meals {
            lines.append(contentsOf: meals.lines)
        } else {
            lines.append("- Meals are planned and pre-ticked; unticked or swapped meals are adjusted in the app.")
        }
        // C4: this week's social meals; over the allowance is flagged for Claude.
        // One line only: the adherence block's count wins when it has one.
        let social = SocialMeals.count(socialMeals, weekOf: AlarmSchedule.mondayOf(now, calendar: calendar), calendar: calendar)
        if social.used > 0, meals?.socialMeals == nil {
            lines.append("- Social meals this week: \(social.text)" + (social.flagged ? " (over the allowance, flagged)" : "")
                         + ", counted as \(CoachText.thousands(SocialMeals.kcal)) kcal each, untracked")
        }
        lines.append("")

        lines.append("Training (last 14 days)")
        let window = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: now)) ?? now
        let recent = history.filter { $0.startedAt >= window && $0.startedAt <= now }
        let planned = plannedSessions(programme: programme, start: start, from: window, to: now, calendar: calendar)
        lines.append("- Sessions done: \(recent.filter(\.isComplete).count) of \(planned) planned")
        if let recovery = RecoverySummary.make(history: history, now: now, calendar: calendar) {
            lines.append(recovery.line)
        }
        if let easing = programme.easing(history: history, on: now, calendar: calendar) {
            lines.append(easing.summaryLine)
        }
        if !review.droppedSessions.isEmpty {
            lines.append("- Left out this week: " + review.droppedSessions.sorted().joined(separator: ", "))
        }
        lines.append("- Next loads (per dumbbell):")
        var exampleLoad: CoachBlock.Load?
        for item in programme.strengthItems where item.startKg != nil {
            guard let week = programmeWeek,
                  let rx = programme.prescription(for: item, week: week, history: history, blocks: blocks,
                                                  on: now, calendar: calendar),
                  let kg = rx.kg else { continue }
            let target = rx.reps.map { "\($0) reps" } ?? rx.seconds.map { "\($0) s" } ?? ""
            lines.append("  - \(rx.exercise): \(CoachText.kg(kg)) × \(target)")
            if exampleLoad == nil { exampleLoad = .init(exercise: rx.exercise, kg: kg) }
        }
        if !review.dumbbellLimit.isEmpty {
            lines.append("- Dumbbells now the limit for: " + review.dumbbellLimit.joined(separator: ", "))
        }
        lines.append("")

        if !review.flags.isEmpty {
            lines.append("Flags")
            for flag in review.flags { lines.append("- \(flag.line)") }
            lines.append("")
        }

        lines.append(contentsOf: replyInstructions(programme: programme, profile: profile, review: review,
                                                  exampleLoad: exampleLoad))
        return lines.joined(separator: "\n")
    }

    /// The part that tells Claude how to answer so the reply imports.
    /// The example uses today's numbers, so a block copied unedited changes nothing by accident.
    static func replyInstructions(programme: Programme, profile: Profile, review: CoachReview,
                                  exampleLoad: CoachBlock.Load?) -> [String] {
        let maintenance = CalorieRules.isMaintenance(week: review.week + 1) || CalorieRules.isMaintenance(week: review.week)
        let band = maintenance ? CalorieRules.importMaintenanceBand : CalorieRules.importCutBand
        let protein = CalorieRules.importProteinG
        let droppable = programme.sessions.keys.sorted().filter { id in
            if case .walk = programme.sessions[id] { return false }
            if case let .circuit(c) = programme.sessions[id], c.swapOnly == true { return false }
            return true
        }
        let limit = min(programme.dumbbellLimitKg, profile.training.dumbbellMaxKg)
        return [
            "Please reply",
            "Give your advice in a few plain sentences. Then, only if something should change, end with one block exactly like this (format \(CoachBlock.currentSchemaVersion)); I'll copy your reply and the app applies it from tomorrow:",
            "",
            CoachImport.beginMarker,
            "{\"format\": \"\(CoachBlock.format)\", \"schemaVersion\": \(CoachBlock.currentSchemaVersion), \"note\": \"One line I'll see on Today\", \"dailyKcal\": \(review.calories.kcal), \"proteinG\": \(review.calories.proteinG), \"dropSessions\": [], \"dropForWeeks\": 1, \"loads\": [\(exampleLoad.map { "{\"exercise\": \"\($0.exercise)\", \"kg\": \(CoachText.number($0.kg))}" } ?? "")]}",
            CoachImport.endMarker,
            "",
            "Rules (anything else and the app rejects the whole block):",
            "- Every field except format and schemaVersion is optional; leave out what shouldn't change. No other fields.",
            "- dailyKcal: \(CoachText.thousands(band.lowerBound))–\(CoachText.thousands(band.upperBound)). proteinG: \(protein.lowerBound)–\(protein.upperBound). The app then moves calories by at most 100 a week from the weight trend.",
            "- dropSessions: any of \(droppable.joined(separator: ", ")), for dropForWeeks 1–\(CoachImport.maxDropForWeeks) weeks. Keep at least \(CoachImport.minimumStrengthSessionsKept) strength sessions. Sessions can't be added or moved.",
            "- loads: dumbbell exercises listed above, in \(CoachText.kg(programme.loadStepKg)) steps, up to \(CoachText.kg(limit)). Progression carries on from the new weight.",
            "- note: up to \(CoachImport.maxNoteLength) characters.",
        ]
    }

    /// Sessions the programme has on days in `from..<to`, leaving out optional walks and swap-only circuits.
    public static func plannedSessions(programme: Programme, start: Date, from: Date, to: Date, calendar: Calendar) -> Int {
        var count = 0
        var day = calendar.startOfDay(for: from)
        while day < to {
            if case let .session(_, session) = programme.plannedDay(on: day, start: start, calendar: calendar).entry {
                switch session {
                case let .walk(w) where w.optional: break
                case let .circuit(c) where c.swapOnly == true: break
                default: count += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }

    static func reasonText(_ reason: CalorieTarget.Reason) -> String {
        switch reason {
        case .start: "starting target"
        case .maintenance: "maintenance break"
        case .onTrack: "on track at the last check"
        case .steppedDown: "down 100 at the last check: losing slowly"
        case .steppedUp: "up 100 at the last check: losing fast"
        case .atFloor: "at the 1,850 floor"
        case .atCeiling: "at the 2,200 ceiling"
        case .notEnoughWeighIns: "unchanged: too few weigh-ins to judge"
        case .settling: "unchanged while weight settles after a change"
        case .imported: "set by your last reply"
        }
    }

    static func range(_ r: ClosedRange<Double>) -> String {
        "\(CoachText.number(r.lowerBound))–\(CoachText.number(r.upperBound))"
    }
}

/// Number and date text without `String(format:)`, which differs on Linux.
enum CoachText {
    /// "2,000".
    static func thousands(_ value: Int) -> String {
        let digits = String(abs(value))
        var out = ""
        for (index, char) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 { out.append(",") }
            out.append(char)
        }
        return value < 0 ? "-" + out : out
    }

    /// "12", "12.5": whole numbers lose the ".0".
    static func number(_ value: Double) -> String {
        let tenths = Int((value * 10).rounded())
        return tenths % 10 == 0 ? "\(tenths / 10)" : WeightTrend.oneDecimal(value)
    }

    /// "12 kg", "0.4 kg".
    static func kg(_ value: Double) -> String { "\(number(value)) kg" }

    /// "Sun 27 Dec 2026".
    static func day(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE d MMM yyyy"
        return formatter.string(from: date)
    }
}
