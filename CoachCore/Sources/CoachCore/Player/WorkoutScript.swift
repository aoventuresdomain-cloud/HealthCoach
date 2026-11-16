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

    /// nil when `sessionID` isn't a strength session.
    /// Used only if a block's rest is missing or zero; every Phase 1 block
    /// sets its own (Advisor condition on M1-06).
    public static let fallbackRestSeconds = 90

    static func restSeconds(for block: StrengthSession.Block) -> Int {
        block.restSeconds > 0 ? block.restSeconds : fallbackRestSeconds
    }

    public static func make(sessionID: String, programme: Programme, week: Int,
                            loads: [String: Double] = [:]) -> WorkoutScript? {
        guard case let .strength(session) = programme.sessions[sessionID] else { return nil }
        let effort = programme.effort.first { $0.week == week }

        var steps: [SetStep] = []
        var exerciseNumber = 0
        for block in session.blocks {
            for item in block.items {
                let count = item.sets[safe: week - 1] ?? 0
                guard count > 0 else { continue }
                exerciseNumber += 1
                let kind = Self.kind(of: item, week: week)
                let kg = loads[item.exercise] ?? item.startKg
                for index in 0..<count {
                    steps.append(SetStep(
                        exercise: item.exercise, kind: kind, kg: kg, setIndex: index, setCount: count,
                        exerciseNumber: exerciseNumber,
                        repsInReserve: item.repsInReserve[safe: week - 1] ?? effort?.repsInReserve,
                        cue: kind.isLoaded ? effort?.cue : nil,
                        note: item.note, restSeconds: Self.restSeconds(for: block)))
                }
            }
        }
        // Nothing to rest for after the last set.
        if let last = steps.popLast() {
            steps.append(SetStep(exercise: last.exercise, kind: last.kind, kg: last.kg, setIndex: last.setIndex,
                                 setCount: last.setCount, exerciseNumber: last.exerciseNumber,
                                 repsInReserve: last.repsInReserve, cue: last.cue, note: last.note, restSeconds: 0))
        }
        let warmUp = session.warmUp.map { WarmUpStep(exercise: $0.exercise, reps: $0.reps, perSide: $0.perSide, kg: $0.startKg) }
        let perMove = warmUp.isEmpty ? 0 : session.warmUpMinutes * 60 / warmUp.count
        return WorkoutScript(sessionID: sessionID, name: session.name, week: week, warmUp: warmUp,
                             warmUpSecondsPerMove: perMove, sets: steps, exerciseCount: exerciseNumber)
    }

    static func kind(of item: StrengthItem, week: Int) -> SetStep.Kind {
        if let seconds = item.seconds {
            return .hold(seconds: seconds.min)
        }
        let target = item.reps?.min ?? 0
        if item.progression == .repsThenGraduate {
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
