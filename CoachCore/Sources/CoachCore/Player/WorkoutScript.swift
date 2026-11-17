import Foundation

/// A strength session for one week, flattened into the steps the workout
/// player walks through (board M1-06): warm-up moves, then every working set
/// in programme order, each with the rest that follows it. Every number comes
/// from the programme data; loads can be overridden by progression (M1-08).
public struct WorkoutScript: Equatable, Sendable {
    public let sessionID: String
    public let name: String
    public let week: Int
    public let warmUp: [WarmUpStep]
    /// Seconds per warm-up move: the warm-up minutes shared across the moves.
    public let warmUpSecondsPerMove: Int
    public let sets: [SetStep]
    /// Distinct exercises with at least one set this week, in order.
    public let exerciseCount: Int

    public struct WarmUpStep: Equatable, Sendable {
        public let exercise: String
        public let reps: Int
        public let perSide: Bool
        public let kg: Double?
    }

    public struct SetStep: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            /// Reps × kg (kg nil = bodyweight).
            case reps(target: Int)
            /// One side, then the other with no rest between.
            case perSide(target: Int)
            /// Timed hold; the countdown starts by itself.
            case hold(seconds: Int)
            /// Slow lowerings, voice-paced; no load.
            case negatives(reps: Int, lowerSeconds: Int)
        }

        public let exercise: String
        public let kind: Kind
        /// Per dumbbell; nil = bodyweight.
        public let kg: Double?
        /// 0-based within the item.
        public let setIndex: Int
        public let setCount: Int
        /// 1-based position among the session's exercises.
        public let exerciseNumber: Int
        public let repsInReserve: Int?
        public let cue: String?
        public let note: String?
        /// Rest after this set; 0 after the last set of the session.
        public let restSeconds: Int
        /// Lower over 3 seconds this session (the tempo step).
        public let slowTempo: Bool
        /// The next load step is past the heaviest dumbbell (decision D3).
        public let atDumbbellLimit: Bool
        /// On an item's first set only: switch the rest of its sets if this one falls short.
        public let swap: Swap?

        public struct Swap: Equatable, Sendable {
            public let whenFirstSetRepsBelow: Int
            public let exercise: String
            public let kind: Kind
            public let kg: Double?
            public let note: String?
        }

        func with(restSeconds: Int) -> SetStep {
            SetStep(exercise: exercise, kind: kind, kg: kg, setIndex: setIndex, setCount: setCount,
                    exerciseNumber: exerciseNumber, repsInReserve: repsInReserve, cue: cue, note: note,
                    restSeconds: restSeconds, slowTempo: slowTempo, atDumbbellLimit: atDumbbellLimit, swap: swap)
        }

        /// What "done as prescribed" logs for this set.
        public func prescribedLog() -> SetLog {
            switch kind {
            case let .reps(target), let .perSide(target):
                SetLog(exercise: exercise, setIndex: setIndex, reps: target, kg: kg, asPrescribed: true)
            case let .hold(seconds):
                SetLog(exercise: exercise, setIndex: setIndex, seconds: seconds, kg: kg, asPrescribed: true)
            case let .negatives(reps, _):
                SetLog(exercise: exercise, setIndex: setIndex, reps: reps, kg: kg, asPrescribed: true)
            }
        }

        /// Log from the tap counter (reps) or the hold clock (seconds). Hitting
        /// the target counts as prescribed; short sets are logged as they were.
        public func log(counted: Int) -> SetLog {
            switch kind {
            case let .reps(target), let .perSide(target), let .negatives(target, _):
                SetLog(exercise: exercise, setIndex: setIndex, reps: counted, kg: kg, asPrescribed: counted >= target)
            case let .hold(seconds):
                SetLog(exercise: exercise, setIndex: setIndex, seconds: counted, kg: kg, asPrescribed: counted >= seconds)
            }
        }
    }

    /// Used only if a block's rest is missing or zero; every Phase 1 block
    /// sets its own (Advisor condition on M1-06).
    public static let fallbackRestSeconds = 90

    static func restSeconds(for block: StrengthSession.Block) -> Int {
        block.restSeconds > 0 ? block.restSeconds : fallbackRestSeconds
    }

    /// The script for `week`, with each item's targets and weight from
    /// `Programme.prescription` over `history` (board M1-08), so the player
    /// shows next session's numbers, not the programme's starting ones.
    /// Accepted Claude `blocks` in force on `date` set a load until that
    /// exercise is next logged (board M4-02).
    /// nil when `sessionID` isn't a strength session.
    public static func make(sessionID: String, programme: Programme, week: Int,
                            history: [SessionLog] = [], blocks: [CoachBlock] = [],
                            on date: Date = .distantPast, calendar: Calendar = .current) -> WorkoutScript? {
        guard case let .strength(session) = programme.sessions[sessionID] else { return nil }
        let effort = programme.effort.first { $0.week == week }

        var steps: [SetStep] = []
        var exerciseNumber = 0
        for block in session.blocks {
            for item in block.items {
                guard let prescription = programme.prescription(for: item, week: week, history: history,
                                                                blocks: blocks, on: date, calendar: calendar) else { continue }
                exerciseNumber += 1
                let swap = programme.swapPrescription(for: item, week: week, history: history).flatMap { swapped in
                    item.autoSwap.map { rule in
                        SetStep.Swap(whenFirstSetRepsBelow: rule.whenFirstSetRepsBelow, exercise: swapped.exercise,
                                     kind: .reps(target: swapped.reps ?? swapped.range.min), kg: swapped.kg,
                                     note: nil) // the data's note is for us, not the owner
                    }
                }
                let kind = Self.kind(of: item, prescription: prescription)
                for index in 0..<prescription.sets {
                    steps.append(SetStep(
                        exercise: prescription.exercise, kind: kind, kg: prescription.kg,
                        setIndex: index, setCount: prescription.sets, exerciseNumber: exerciseNumber,
                        repsInReserve: kind.isLoaded ? prescription.repsInReserve : nil,
                        cue: kind.isLoaded ? effort?.cue : nil,
                        note: prescription.exercise == item.exercise ? item.note : nil,
                        restSeconds: Self.restSeconds(for: block),
                        slowTempo: prescription.slowTempo, atDumbbellLimit: prescription.atDumbbellLimit,
                        swap: index == 0 ? swap : nil))
                }
            }
        }
        // Nothing to rest for after the last set.
        if let last = steps.popLast() {
            steps.append(last.with(restSeconds: 0))
        }
        let warmUp = session.warmUp.map { WarmUpStep(exercise: $0.exercise, reps: $0.reps, perSide: $0.perSide, kg: $0.startKg) }
        let perMove = warmUp.isEmpty ? 0 : session.warmUpMinutes * 60 / warmUp.count
        return WorkoutScript(sessionID: sessionID, name: session.name, week: week, warmUp: warmUp,
                             warmUpSecondsPerMove: perMove, sets: steps, exerciseCount: exerciseNumber)
    }

    /// After the first set at `index` fell short of its swap threshold, the
    /// item's remaining sets switch to the swap exercise (autoSwap, without asking).
    public func swappingRemainingSets(after index: Int) -> WorkoutScript {
        guard let first = sets[safe: index], let swap = first.swap else { return self }
        let swapped = sets.enumerated().map { offset, step -> SetStep in
            guard offset > index, step.exerciseNumber == first.exerciseNumber else { return step }
            return SetStep(exercise: swap.exercise, kind: swap.kind, kg: swap.kg, setIndex: step.setIndex,
                           setCount: step.setCount, exerciseNumber: step.exerciseNumber,
                           repsInReserve: step.repsInReserve, cue: step.cue, note: swap.note,
                           restSeconds: step.restSeconds, slowTempo: false, atDumbbellLimit: false, swap: nil)
        }
        return WorkoutScript(sessionID: sessionID, name: name, week: week, warmUp: warmUp,
                             warmUpSecondsPerMove: warmUpSecondsPerMove, sets: swapped, exerciseCount: exerciseCount)
    }

    static func kind(of item: StrengthItem, prescription: Prescription) -> SetStep.Kind {
        if let seconds = prescription.seconds {
            return .hold(seconds: seconds)
        }
        let target = prescription.reps ?? prescription.range.min
        if item.progression == .repsThenGraduate, prescription.exercise == item.exercise {
            // Negatives: the tempo's first number is the lowering time ("5-0-x").
            let lower = item.tempo.split(separator: "-").first.flatMap { Int($0) } ?? 3
            return .negatives(reps: target, lowerSeconds: lower)
        }
        return item.perSide ? .perSide(target: target) : .reps(target: target)
    }
}

extension WorkoutScript.SetStep.Kind {
    /// Reps-in-reserve applies to rep sets, not holds or negatives.
    var isLoaded: Bool {
        switch self {
        case .reps, .perSide: true
        case .hold, .negatives: false
        }
    }
}
