import CoachCore
import SwiftUI

/// "Tomorrow changed" (plan §4.1, board M2-06): tomorrow's answers only, from
/// the same pieces as the Sunday prompt. Office or home, plus an early start
/// (which moves the alarm) or a late finish. Pre-filled from the week's
/// answers; Done saves the week with only tomorrow's weekday changed.
struct TomorrowChangedView: View {
    let date: Date
    let day: Weekday
    let workStart: TimeOfDay
    let workEnd: TimeOfDay
    var onDone: (WeekAnswers) -> Void

    @State private var answers: WeekAnswers
    @Environment(\.dismiss) private var dismiss

    init(date: Date, day: Weekday, week: WeekAnswers, workStart: TimeOfDay, workEnd: TimeOfDay,
         onDone: @escaping (WeekAnswers) -> Void) {
        self.date = date
        self.day = day
        self.workStart = workStart
        self.workEnd = workEnd
        self.onDone = onDone
        _answers = State(initialValue: week)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Where are you tomorrow?")
                        .font(.title2.bold())
                        .accessibilityIdentifier("tomorrow.question")
                    HStack(spacing: 8) {
                        placeButton("Office", office: true)
                        placeButton("Home", office: false)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        timeToggle("Early start", keyPath: \.earlyStarts, default: workStart.adding(minutes: -60), id: "tomorrow.early")
                        timeToggle("Late finish", keyPath: \.lateFinishes, default: workEnd.adding(minutes: 90), id: "tomorrow.late")
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.surface, in: .rect(cornerRadius: Radius.card))
                    Text("Only tomorrow's alarm and reminders change.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.canvas)
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("tomorrow.cancel")
                }
            }
            .safeAreaInset(edge: .bottom) {
                ActionBar {
                    Button("Done") {
                        onDone(cleaned(answers))
                        dismiss()
                    }
                    .buttonStyle(PrimaryActionStyle())
                    .accessibilityIdentifier("tomorrow.done")
                }
            }
        }
    }

    private func placeButton(_ title: String, office: Bool) -> some View {
        let on = answers.officeDays.contains(day) == office
        return Button {
            if office { answers.officeDays.insert(day) } else { answers.officeDays.remove(day) }
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(on ? Color.onGo : Color.primary)
                .background(on ? Color.go : Color.surface, in: .rect(cornerRadius: Radius.pill))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(office ? "tomorrow.office" : "tomorrow.home")
    }

    private func timeToggle(_ title: String, keyPath: WritableKeyPath<WeekAnswers, [Weekday: TimeOfDay]>,
                            default fallback: TimeOfDay, id: String) -> some View {
        let isOn = Binding<Bool>(
            get: { answers[keyPath: keyPath][day] != nil },
            set: { answers[keyPath: keyPath][day] = $0 ? fallback : nil })
        let time = Binding<Date>(
            get: { SundayPrompt.date(answers[keyPath: keyPath][day] ?? fallback) },
            set: { answers[keyPath: keyPath][day] = SundayPrompt.time($0) })
        return HStack {
            Toggle(title, isOn: isOn)
                .accessibilityIdentifier(id)
            if isOn.wrappedValue {
                DatePicker(title, selection: time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .accessibilityIdentifier("\(id).time")
            }
        }
    }

    /// Same rule as the Sunday prompt: times inside the normal day mean nothing.
    private func cleaned(_ answers: WeekAnswers) -> WeekAnswers {
        var out = answers
        if let early = out.earlyStarts[day], early >= workStart { out.earlyStarts[day] = nil }
        if let late = out.lateFinishes[day], late <= workEnd { out.lateFinishes[day] = nil }
        return out
    }
}
