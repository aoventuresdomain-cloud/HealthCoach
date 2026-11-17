import Foundation

extension Programme {
    /// Rules the decoder can't check, within this file. Empty means valid.
    public func problems() -> [String] {
        var problems: [String] = []
        func check(_ condition: Bool, _ message: @autoclosure () -> String) {
            if !condition { problems.append(message()) }
        }
        let weekRange = 1...max(weeks, 1)
        let fixedIDs = Set(fixed.map(\.id))

        check(weeks > 0, "weeks must be at least 1")
        check(isSlug(id), "id \(id) must be lower-case words joined by hyphens")
        check(loadStepKg > 0, "loadStepKg must be above 0")
        check(dumbbellLimitKg > 0, "dumbbellLimitKg must be above 0")
        check(effort.map(\.week) == Array(weekRange), "effort must list weeks 1–\(weeks) in order")
        for missing in Progression.allCases.map(\.rawValue) where progressionRules[missing] == nil {
            problems.append("progressionRules has no description for \(missing)")
        }
        for id in sessions.keys where fixedIDs.contains(id) {
            problems.append("\(id) is both a session and a fixed event")
        }

        // Schedule
        check(schedule.map(\.week) == Array(weekRange), "schedule must list weeks 1–\(weeks) in order")
        for week in schedule {
            let missingDays = Weekday.allCases.filter { week.days[$0] == nil }
            if !missingDays.isEmpty {
                problems.append("schedule week \(week.week): no entry for \(missingDays.map(\.rawValue).joined(separator: ", ")) (use null for rest)")
            }
            for (day, entry) in week.days.sorted(by: { $0.key < $1.key }) {
                guard let entry else { continue }
                if sessions[entry] == nil && !fixedIDs.contains(entry) {
                    problems.append("schedule week \(week.week) \(day.rawValue): \(entry) is not a session or fixed event")
                }
                if placementRules.neverOn.contains(day) && !fixedIDs.contains(entry) {
                    problems.append("schedule week \(week.week): \(entry) is on \(day.rawValue), which is a no-session day")
                }
                if case let .runWalk(run)? = sessions[entry], !run.weeks.contains(where: { $0.week == week.week }) {
                    problems.append("schedule week \(week.week): \(entry) has no plan for week \(week.week)")
                }
            }
        }

        // Placement and reduced week refer to real things
        for (event, banned) in placementRules.notTheDayBefore {
            check(fixedIDs.contains(event), "placementRules.notTheDayBefore: \(event) is not a fixed event")
            for id in banned { check(sessions[id] != nil, "placementRules.notTheDayBefore.\(event): \(id) is not a session") }
        }
        for id in placementRules.outdoorSessions { check(sessions[id] != nil, "placementRules.outdoorSessions: \(id) is not a session") }
        for id in reducedWeek.drop + reducedWeek.keep { check(sessions[id] != nil, "reducedWeek: \(id) is not a session") }

        // Sessions
        for (sessionID, session) in sessions.sorted(by: { $0.key < $1.key }) {
            switch session {
            case let .strength(strength):
                check(strength.durationMinutes.count == weeks, "\(sessionID).durationMinutes needs \(weeks) values")
                for (index, minutes) in strength.durationMinutes.enumerated() where minutes > maxSessionMinutes {
                    problems.append("\(sessionID) week \(index + 1): \(minutes) min is over the \(maxSessionMinutes) min cap")
                }
                for block in strength.blocks {
                    check(block.restSeconds > 0, "\(sessionID) block \(block.label): restSeconds must be above 0")
                    for item in block.items {
                        problems += item.problems(at: "\(sessionID) \(block.label) \(item.exercise)", weeks: weeks, dumbbellLimitKg: dumbbellLimitKg)
                    }
                }
            case let .runWalk(run):
                let numbers = run.weeks.map(\.week)
                check(Set(numbers).count == numbers.count, "\(sessionID): a week appears twice")
                for week in run.weeks {
                    check(weekRange.contains(week.week), "\(sessionID): week \(week.week) is outside 1–\(weeks)")
                    check(week.intervals.repeats > 0 && week.intervals.jogSeconds > 0, "\(sessionID) week \(week.week): intervals must be above 0")
                    if let swap = week.indoorSwap {
                        if case .circuit? = sessions[swap.session] {} else {
                            problems.append("\(sessionID) week \(week.week): indoor swap \(swap.session) is not a circuit session")
                        }
                        // The weather swap keeps the run's slot, so the wake time holds (M2-03).
                        check(swap.durationMinutes <= week.durationMinutes,
                              "\(sessionID) week \(week.week): indoor swap is longer than the run (\(swap.durationMinutes) > \(week.durationMinutes) min)")
                    }
                }
            case let .circuit(circuit):
                check(!circuit.round.items.isEmpty, "\(sessionID): round has no items")
                for item in circuit.round.items {
                    if let kg = item.startKg { check(kg <= dumbbellLimitKg, "\(sessionID) \(item.exercise): \(kg) kg is over the \(dumbbellLimitKg) kg dumbbell limit") }
                }
            case let .walk(walk):
                check(walk.durationMinutes.count == weeks, "\(sessionID).durationMinutes needs \(weeks) values")
            }
        }
        return problems
    }

    /// Every exercise id this programme names, with where, for checking
    /// against the catalogue.
    public func exerciseReferences() -> [(id: String, at: String)] {
        var refs: [(String, String)] = []
        for (sessionID, session) in sessions.sorted(by: { $0.key < $1.key }) {
            switch session {
            case let .strength(strength):
                refs += strength.warmUp.map { ($0.exercise, "\(sessionID) warm-up") }
                for block in strength.blocks {
                    for item in block.items {
                        refs.append((item.exercise, "\(sessionID) \(block.label)"))
                        if let to = item.graduate?.to { refs.append((to, "\(sessionID) \(item.exercise) graduate")) }
                        if let to = item.autoSwap?.to { refs.append((to, "\(sessionID) \(item.exercise) autoSwap")) }
                    }
                }
            case let .circuit(circuit):
                refs += circuit.warmUp.map { ($0.exercise, "\(sessionID) warm-up") }
                refs += circuit.round.items.map { ($0.exercise, "\(sessionID) round") }
            case .runWalk, .walk:
                break
            }
        }
        return refs.map { (id: $0.0, at: $0.1) }
    }

    /// Cross-file check: every exercise named here exists in the catalogue.
    public func problems(against catalogue: ExerciseCatalogue) -> [String] {
        let known = Set(catalogue.exercises.map(\.id))
        return exerciseReferences()
            .filter { !known.contains($0.id) }
            .map { "\($0.at): \($0.id) is not in exercises.json" }
    }
}

extension StrengthItem {
    func problems(at place: String, weeks: Int, dumbbellLimitKg: Double) -> [String] {
        var problems: [String] = []
        func check(_ condition: Bool, _ message: @autoclosure () -> String) {
            if !condition { problems.append("\(place): \(message())") }
        }
        check(sets.count == weeks, "sets needs \(weeks) values")
        check(repsInReserve.count == weeks, "repsInReserve needs \(weeks) values")
        check(sets.allSatisfy { $0 >= 0 }, "sets can't be negative")
        check((reps == nil) != (seconds == nil), "set exactly one of reps and seconds")
        if progression.isTimed {
            check(seconds != nil, "\(progression.rawValue) progression needs seconds")
        } else {
            check(reps != nil, "\(progression.rawValue) progression needs reps")
        }
        for (label, range) in [("reps", reps), ("seconds", seconds)] {
            if let range { check(range.min > 0 && range.min <= range.max, "\(label) range \(range.min)–\(range.max) is invalid") }
        }
        if let kg = startKg { check(kg > 0 && kg <= dumbbellLimitKg, "startKg \(kg) must be above 0 and at most \(dumbbellLimitKg)") }
        check((graduate != nil) == (progression == .repsThenGraduate), "graduate goes with, and only with, reps-then-graduate")
        if let swap = autoSwap, let kg = swap.startKg {
            check(kg <= dumbbellLimitKg, "autoSwap startKg \(kg) is over the dumbbell limit")
        }
        return problems
    }
}
