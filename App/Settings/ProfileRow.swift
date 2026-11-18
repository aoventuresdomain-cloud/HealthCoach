import CoachCore
import SwiftUI

/// The profile's editable rows, shared by onboarding confirm (M1-04) and
/// Settings → Preferences (N3).
enum ProfileRow: String, CaseIterable, Identifiable {
    case you, goal, hurts, paperStart, sleep, work, office, fixed, kit, longest, cues, checkIn, food
    var id: String { rawValue }
}

/// One row: label, current value, and an inline editor on tap.
struct ProfileRowView: View {
    typealias Row = ProfileRow

    @Binding var profile: Profile
    let programme: Programme
    let row: Row
    @Binding var editing: Row?
    /// "onboarding" keeps onboarding's ids; Preferences passes "preferences".
    var idPrefix = "onboarding"
    /// Onboarding marks the unconfirmed defaults; Preferences doesn't.
    var showsGuess = true
    /// Ingredient names to pick dislikes from (Preferences).
    var dislikeOptions: [String] = []

    var body: some View { content(row) }

    @ViewBuilder
    private func content(_ row: Row) -> some View {
        let editable = hasEditor(row)
        VStack(alignment: .leading, spacing: 12) {
            Button {
                guard editable else { return }
                withAnimation(.snappy) { editing = editing == row ? nil : row }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(label(row))
                        .foregroundStyle(.primary)
                    if showsGuess, isGuess(row) { GuessTag() }
                    Spacer(minLength: 12)
                    Text(value(row))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("\(idPrefix).value.\(row.rawValue)")
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(idPrefix).row.\(row.rawValue)")
            .accessibilityHint(editable ? "Tap to change" : "")

            if editing == row {
                editor(row)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }

    func label(_ row: Row) -> String {
        switch row {
        case .you: "You"
        case .goal: "Goal"
        case .hurts: "Anything that hurts"
        case .paperStart: "Started on paper"
        case .sleep: "Sleep"
        case .work: "Work hours"
        case .office: "Office days"
        case .fixed: "Fixed"
        case .kit: "Kit"
        case .longest: "Longest session"
        case .cues: "Timers and counting"
        case .checkIn: "Weekly check-in"
        case .food: "Foods I don't eat"
        }
    }

    /// Requirements §12 left only these "to confirm" (design B9); the paper
    /// start date is a guess too (decision E13).
    private func isGuess(_ row: Row) -> Bool {
        [.paperStart, .sleep, .work, .longest].contains(row)
    }

    func hasEditor(_ row: Row) -> Bool {
        ![.office, .fixed].contains(row)
    }

    func value(_ row: Row) -> String {
        let p = profile
        switch row {
        case .you:
            let parts = [p.about.heightCm.map { "\(Int($0)) cm" }, p.about.weightKg.map { "\(OnboardingFormat.kg($0)) kg" }].compactMap { $0 }
            return parts.isEmpty ? "Add height and weight" : parts.joined(separator: " · ")
        case .goal:
            return "\(OnboardingFormat.target(p.goal.target)) · \(p.goal.phaseWeeks)-week phase"
        case .paperStart:
            guard let start = p.programme.startDate else { return "Not yet" }
            return start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case .hurts:
            return p.about.painAreas.isEmpty ? "Nothing" : p.about.painAreas.map(OnboardingFormat.area).joined(separator: ", ")
        case .sleep:
            return "\(OnboardingFormat.hours(p.schedule.sleepHours)) h asleep, timed from a \(p.schedule.earliestWake) alarm"
        case .work:
            return "\(p.schedule.workStart)–\(p.schedule.workEnd)"
        case .office:
            return "Asked each Sunday"
        case .fixed:
            let fixed = programme.fixed.map { "\($0.name), \($0.day.rawValue.capitalized) \($0.time)" }
            return fixed.isEmpty ? "None" : fixed.joined(separator: "; ")
        case .kit:
            var kit = ["Dumbbells to \(OnboardingFormat.kg(p.training.dumbbellMaxKg)) kg"]
            if p.training.hasBench { kit.append("bench") }
            if p.training.hasPullUpBar { kit.append("bar") }
            return kit.joined(separator: ", ")
        case .longest:
            return "\(p.training.maxSessionMinutes) min"
        case .cues:
            return "\(p.training.voiceCues ? "Voice on" : "Voice off") · \(OnboardingFormat.counting(p.training.counting))"
        case .checkIn:
            return "\(p.coach.checkInDay.rawValue.capitalized) \(p.coach.checkInTime) · quiet \(p.coach.quietFrom)–\(p.coach.quietUntil)"
        case .food:
            return p.food.dislikes.isEmpty ? "None" : p.food.dislikes.joined(separator: ", ")
        }
    }

    // MARK: Inline editors

    /// The dislikes list for a host form that owns the search field.
    func dislikes(search: Binding<String>) -> some View {
        DislikesEditor(dislikes: $profile.food.dislikes, options: dislikeOptions, search: search)
    }

    @ViewBuilder
    func editor(_ row: Row) -> some View {
        switch row {
        case .you:
            Stepper(value: optional($profile.about.heightCm, default: 175), in: 140...210, step: 1) {
                Text("Height \(Int(profile.about.heightCm ?? 175)) cm")
            }
            Stepper(value: optional($profile.about.weightKg, default: 75), in: 40...200, step: 0.5) {
                Text("Weight \(OnboardingFormat.kg(profile.about.weightKg ?? 75)) kg")
            }
        case .goal:
            Picker("Target", selection: $profile.goal.target) {
                ForEach(Profile.Goal.Target.allCases, id: \.self) { Text(OnboardingFormat.target($0)).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            Stepper("Phase \(profile.goal.phaseWeeks) weeks", value: $profile.goal.phaseWeeks, in: 4...12)
        case .hurts:
            ForEach(OnboardingFormat.areas, id: \.self) { area in
                Toggle(OnboardingFormat.area(area), isOn: painBinding(area))
            }
        case .paperStart:
            // E13: the week number counts from here; always a Monday.
            DatePicker("Week 1 began", selection: Binding(
                get: { profile.programme.startDate ?? OnboardingFlow.paperStart },
                set: { profile.programme.startDate = AlarmSchedule.mondayOf($0, calendar: .coach) }
            ), in: ...AppClock.now(), displayedComponents: .date)
            .accessibilityIdentifier("onboarding.paperStartPicker")
        case .sleep:
            Stepper("\(OnboardingFormat.hours(profile.schedule.sleepHours)) h asleep", value: $profile.schedule.sleepHours, in: 6...9, step: 0.25)
            TimeOfDayPicker(title: "Alarm", time: $profile.schedule.earliestWake)
        case .work:
            TimeOfDayPicker(title: "Start", time: $profile.schedule.workStart)
            TimeOfDayPicker(title: "End", time: $profile.schedule.workEnd)
        case .kit:
            Stepper("Dumbbells to \(OnboardingFormat.kg(profile.training.dumbbellMaxKg)) kg", value: $profile.training.dumbbellMaxKg, in: 5...50, step: 1)
            Toggle("Bench", isOn: $profile.training.hasBench)
            Toggle("Pull-up bar", isOn: $profile.training.hasPullUpBar)
        case .longest:
            Stepper("\(profile.training.maxSessionMinutes) min", value: $profile.training.maxSessionMinutes, in: 20...90, step: 5)
        case .cues:
            Toggle("Voice cues", isOn: $profile.training.voiceCues)
            Picker("Counting", selection: $profile.training.counting) {
                ForEach(Profile.Training.Counting.allCases, id: \.self) { Text(OnboardingFormat.counting($0)).tag($0) }
            }
            .pickerStyle(.segmented)
        case .checkIn:
            Picker("Day", selection: $profile.coach.checkInDay) {
                ForEach(Weekday.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            TimeOfDayPicker(title: "Check-in", time: $profile.coach.checkInTime)
            TimeOfDayPicker(title: "Quiet from", time: $profile.coach.quietFrom)
            TimeOfDayPicker(title: "Quiet until", time: $profile.coach.quietUntil)
        case .food:
            DislikesEditor(dislikes: $profile.food.dislikes, options: dislikeOptions, search: .constant(""))
        case .office, .fixed:
            EmptyView()
        }
    }

    private func optional(_ binding: Binding<Double?>, default value: Double) -> Binding<Double> {
        Binding(get: { binding.wrappedValue ?? value }, set: { binding.wrappedValue = $0 })
    }

    private func painBinding(_ area: String) -> Binding<Bool> {
        Binding(
            get: { profile.about.painAreas.contains(area) },
            set: { on in
                profile.about.painAreas.removeAll { $0 == area }
                if on { profile.about.painAreas.append(area) }
            }
        )
    }
}

/// "Foods I don't eat" (N3, Advisor A4f): picked from the ingredients the
/// recipes use, with search; anything else can be added from the search
/// text. Empty by default; the meal plan never uses them.
/// The host puts `.searchable(text:)` on its form, bound to `search`.
struct DislikesEditor: View {
    @Binding var dislikes: [String]
    let options: [String]
    @Binding var search: String

    private var shown: [String] {
        let all = Array(Set(options + dislikes)).sorted()
        let term = search.trimmingCharacters(in: .whitespaces)
        return term.isEmpty ? all : all.filter { $0.localizedCaseInsensitiveContains(term) }
    }

    var body: some View {
        ForEach(shown, id: \.self) { food in
            Button {
                toggle(food)
            } label: {
                HStack {
                    Text(food).foregroundStyle(.primary)
                    Spacer()
                    if dislikes.contains(food) {
                        Image(systemName: "checkmark").foregroundStyle(Color.go)
                    }
                }
                .contentShape(.rect)
            }
            .accessibilityAddTraits(dislikes.contains(food) ? .isSelected : [])
            .accessibilityIdentifier("prefs.dislike.\(food)")
        }
        let term = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !term.isEmpty, !shown.contains(where: { $0.lowercased() == term }) {
            Button("Add \u{201C}\(term)\u{201D}") {
                toggle(term)
                search = ""
            }
            .accessibilityIdentifier("prefs.dislikeAdd")
        }
    }

    private func toggle(_ food: String) {
        if dislikes.contains(food) { dislikes.removeAll { $0 == food } } else { dislikes.append(food) }
    }
}
