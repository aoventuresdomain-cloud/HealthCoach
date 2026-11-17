import Foundation

/// Spoken lines for the workout player, kept here so they're unit-tested.
public enum PlayerCues {
    /// Seconds before a rest ends when the voice names what's next (board M1-06).
    public static let headsUpSeconds = 10

    /// "10 seconds. Next, Dumbbell one-arm row, 12 kilos." Bodyweight moves
    /// leave the weight out.
    public static func restHeadsUp(exerciseName: String, kg: Double?) -> String {
        let load = kg.map { ", \(kilos($0)) kilos" } ?? ""
        return "\(headsUpSeconds) seconds. Next, \(exerciseName)\(load)."
    }

    /// Whole kilos without a decimal ("12"), halves with one ("12.5").
    public static func kilos(_ kg: Double) -> String {
        let tenths = (kg * 10).rounded()
        return tenths.truncatingRemainder(dividingBy: 10) == 0
            ? String(Int(tenths / 10))
            : String(format: "%.1f", tenths / 10)
    }
}
