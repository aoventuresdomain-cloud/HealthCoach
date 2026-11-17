import CoachCore
import SwiftUI

/// Onboarding confirm (board M1-04, design screen 7): one scroll of rows
/// pre-filled from the profile defaults (decision E6), edited inline, then
/// "Looks right". Only the three unconfirmed defaults are marked Guess.
struct OnboardingConfirmView: View {
    @Binding var profile: Profile
    let programme: Programme
    var onConfirm: () -> Void

    @State private var editing: Row?
    @State private var showingMore = false

    /// UI-12: the guesses and the safety default, which need a glance (Advisor).
    static let toCheck: [Row] = [.paperStart, .sleep, .work, .longest, .hurts]
    /// Confirmed already from what the owner said; one tap away.
    static let rest: [Row] = [.you, .goal, .office, .fixed, .kit, .cues, .checkIn]

    enum Row: String, CaseIterable, Identifiable {
        case you, goal, hurts, paperStart, sleep, work, office, fixed, kit, longest, cues, checkIn
        var id: String { rawValue }
    }

    var body: some View {
        List {
            Section {
                Text("Check this, then you're set")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("onboarding.title")
                if LaunchOptions.current.isUITest {
                    UITestStatus()
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            Section {
                ForEach(Self.toCheck) { row($0) }
            } header: {
                Text("Check these \(Self.toCheck.count)")
            }
            Section {
                Button {
                    withAnimation(.snappy) { showingMore.toggle() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Everything else (\(Self.rest.count))").foregroundStyle(.primary)
                            Text("From what you told us").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(showingMore ? 90 : 0))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(showingMore ? .isSelected : [])
                .accessibilityIdentifier("onboarding.more")
                if showingMore {
                    ForEach(Self.rest) { row($0) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button("Looks right", action: onConfirm)
                    .buttonStyle(PrimaryActionStyle())
                    .accessibilityIdentifier("onboarding.confirm")
            }
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func row(_ row: Row) -> some View {
        let editable = hasEditor(row)
        VStack(alignment: .leading, spacing: 12) {
            Button {
                guard editable else { return }
                withAnimation(.snappy) { editing = editing == row ? nil : row }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(label(row))
                        .foregroundStyle(.primary)
                    if isGuess(row) { GuessTag() }
                    Spacer(minLength: 12)
                    Text(value(row))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("onboarding.value.\(row.rawValue)")
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding.row.\(row.rawValue)")
            .accessibilityHint(editable ? "Tap to change" : "")

            if editing == row {
                editor(row)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }

    private func label(_ row: Row) -> String {
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
        }
    }

    /// Requirements §12 left only these "to confirm" (design B9); the paper
    /// start date is a guess too (decision E13).
    private func isGuess(_ row: Row) -> Bool {
        [.paperStart, .sleep, .work, .longest].contains(row)
    }

    private func hasEditor(_ row: Row) -> Bool {
        ![.office, .fixed].contains(row)
    }

    private func value(_ row: Row) -> String {
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
        }
    }

    // MARK: Inline editors

    @ViewBuilder
    private func editor(_ row: Row) -> some View {
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

/// Edits a `TimeOfDay` with the system wheel, in place.
struct TimeOfDayPicker: View {
    let title: String
    @Binding var time: TimeOfDay

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .gmt
        return c
    }

    var body: some View {
        DatePicker(title, selection: Binding(
            get: { Self.calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: time.hour, minute: time.minute)) ?? .now },
            set: {
                let parts = Self.calendar.dateComponents([.hour, .minute], from: $0)
                time = TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
            }
        ), displayedComponents: .hourAndMinute)
        .environment(\.timeZone, .gmt)
    }
}

enum OnboardingFormat {
    /// Offered under "Anything that hurts"; stored lower-case in the profile.
    static let areas = ["shoulders", "elbows", "wrists", "lower back", "knees"]

    static func area(_ area: String) -> String { area.prefix(1).uppercased() + area.dropFirst() }

    static func target(_ target: Profile.Goal.Target) -> String {
        switch target {
        case .leanAndDefined: "Lean and defined"
        case .leanAndStrong: "Lean and strong"
        case .buildMuscle: "Build muscle"
        case .generalFitness: "General fitness"
        }
    }

    static func counting(_ counting: Profile.Training.Counting) -> String {
        switch counting {
        case .tap: "tap to count"
        case .voice: "count by voice"
        case .both: "tap or voice"
        }
    }

    static func kg(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(0...1)))
    }

    static func hours(_ hours: Double) -> String {
        hours.formatted(.number.precision(.fractionLength(0...2)))
    }
}
