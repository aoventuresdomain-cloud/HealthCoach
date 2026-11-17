import CoachCore
import SwiftUI

/// The Sunday prompt (plan §4.1, board M2-05): which days you're in the
/// office next week, plus any early starts or late finishes. Pre-filled from
/// the latest answers, so a normal week is a few taps and "Done".
struct SundayPromptView: View {
    let monday: Date
    let workStart: TimeOfDay
    let workEnd: TimeOfDay
    var onDone: (WeekAnswers) -> Void

    @State private var answers: WeekAnswers
    @State private var showTimes: Bool
    @Environment(\.dismiss) private var dismiss

    static let workdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]

    init(monday: Date, initial: WeekAnswers, workStart: TimeOfDay, workEnd: TimeOfDay,
         onDone: @escaping (WeekAnswers) -> Void) {
        self.monday = monday
        self.workStart = workStart
        self.workEnd = workEnd
        self.onDone = onDone
        _answers = State(initialValue: initial)
        _showTimes = State(initialValue: !initial.earlyStarts.isEmpty || !initial.lateFinishes.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Office days, week of \(monday.formatted(.dateTime.day().month(.abbreviated)))?")
                        .font(.title2.bold())
                        .accessibilityIdentifier("sunday.question")
                    HStack(spacing: 8) {
                        ForEach(Self.workdays, id: \.self) { day in
                            dayButton(day)
                        }
                    }
                    Button(showTimes ? "Hide early starts and late finishes" : "Early start or late finish?") {
                        withAnimation { showTimes.toggle() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("sunday.times")
                    if showTimes {
                        VStack(spacing: 0) {
                            ForEach(Self.workdays, id: \.self) { day in
                                timesRow(day)
                                if day != .friday { Divider().padding(.leading, 16) }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            // UI-12: the date is in the question; no nav title.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("sunday.cancel")
                }
            }
            .safeAreaInset(edge: .bottom) {
                ActionBar {
                    Button("Done") {
                        onDone(cleaned(answers))
                        dismiss()
                    }
                    .buttonStyle(PrimaryActionStyle())
                    .accessibilityIdentifier("sunday.done")
                }
            }
        }
    }

    private func dayButton(_ day: Weekday) -> some View {
        let on = answers.officeDays.contains(day)
        return Button {
            if on { answers.officeDays.remove(day) } else { answers.officeDays.insert(day) }
        } label: {
            Text(SundayPrompt.short(day))
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(on ? Color.onGo : Color.primary)
                .background(on ? Color.go : Color.surface, in: .rect(cornerRadius: Radius.pill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(SundayPrompt.long(day))
        .accessibilityValue(on ? "Office" : "Home")
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("sunday.day.\(day.rawValue)")
    }

    private func timesRow(_ day: Weekday) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(SundayPrompt.long(day)).font(.headline)
            timeToggle("Early start", day: day, keyPath: \.earlyStarts, default: workStart.adding(minutes: -60))
            timeToggle("Late finish", day: day, keyPath: \.lateFinishes, default: workEnd.adding(minutes: 90))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private func timeToggle(_ title: String, day: Weekday, keyPath: WritableKeyPath<WeekAnswers, [Weekday: TimeOfDay]>,
                            default fallback: TimeOfDay) -> some View {
        let isOn = Binding<Bool>(
            get: { answers[keyPath: keyPath][day] != nil },
            set: { answers[keyPath: keyPath][day] = $0 ? fallback : nil })
        let time = Binding<Date>(
            get: { SundayPrompt.date(answers[keyPath: keyPath][day] ?? fallback) },
            set: { answers[keyPath: keyPath][day] = SundayPrompt.time($0) })
        let id = "sunday.\(title == "Early start" ? "early" : "late").\(day.rawValue)"
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

    /// Drops times that match the normal working day, which mean nothing.
    private func cleaned(_ answers: WeekAnswers) -> WeekAnswers {
        var out = answers
        out.earlyStarts = out.earlyStarts.filter { $0.value < workStart }
        out.lateFinishes = out.lateFinishes.filter { $0.value > workEnd }
        return out
    }
}

/// Helpers for the Sunday prompt and Today's "Plan next week" card.
enum SundayPrompt {
    /// Today shows the card from Saturday until next week is answered.
    static func isDue(on date: Date, calendar: Calendar) -> Bool {
        let day = Weekday(calendarWeekday: calendar.component(.weekday, from: date))
        return day == .saturday || day == .sunday
    }

    /// The week the prompt is about: next week at the weekend, else this one.
    static func monday(for date: Date, calendar: Calendar) -> Date {
        let thisMonday = AlarmSchedule.mondayOf(date, calendar: calendar)
        guard isDue(on: date, calendar: calendar) else { return thisMonday }
        return calendar.date(byAdding: .day, value: 7, to: thisMonday) ?? thisMonday
    }

    static func short(_ day: Weekday) -> String {
        String(day.rawValue.prefix(3)).capitalized
    }

    static func long(_ day: Weekday) -> String {
        day.rawValue.capitalized
    }

    static func date(_ time: TimeOfDay) -> Date {
        Calendar.coach.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date(timeIntervalSinceReferenceDate: 0)) ?? .now
    }

    static func time(_ date: Date) -> TimeOfDay {
        let c = Calendar.coach.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }
}
