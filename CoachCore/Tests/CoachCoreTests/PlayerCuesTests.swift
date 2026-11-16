import Testing
@testable import CoachCore

@Suite struct PlayerCuesTests {
    @Test func headsUpNamesTheNextExerciseAndWeight() {
        #expect(PlayerCues.restHeadsUp(exerciseName: "One-arm row", kg: 12)
                == "10 seconds. Next, One-arm row, 12 kilos.")
    }

    @Test func halfKilosKeepOneDecimal() {
        #expect(PlayerCues.restHeadsUp(exerciseName: "Lateral raise", kg: 7.5)
                == "10 seconds. Next, Lateral raise, 7.5 kilos.")
    }

    @Test func bodyweightLeavesTheWeightOut() {
        #expect(PlayerCues.restHeadsUp(exerciseName: "Plank", kg: nil) == "10 seconds. Next, Plank.")
    }
}
