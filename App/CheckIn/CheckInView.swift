import CoachCore
import SwiftUI

/// N1 · Sunday check-in (ease budget §3), replacing the Sunday prompt card.
/// Two screens, no scrolling on a normal week: "Your week" (weight, one
/// information line, energy, sleep, pain) then "Next week" (office days,
/// what changed, the sessions). Defaults are Good, Fine, None, so an ordinary
/// week is Next, then Looks good.
struct CheckInView: View {
    let monday: Date
    let programme: Programme
    let profile: Profile
    let history: [SessionLog]
    let changes: [CoachChange]
    var onDone: (CheckInAnswers, WeekAnswers) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var checkIn = CheckInAnswers()
    @State private var hasPain = false
    @State private var week: WeekAnswers
    @State private var showTimes: Bool
    @State private var onPlan = false

    private let calendar = Calendar.coach

    init(monday: Date, programme: Programme, profile: Profile, history: [SessionLog], changes: [CoachChange],
         initialWeek: WeekAnswers, onDone: @escaping (CheckInAnswers, WeekAnswers) -> Void) {
        self.monday = monday
        self.programme = programme
        self.profile = profile
        self.history = history
        self.changes = changes
        self.onDone = onDone
        _week = State(initialValue: initialWeek)
        _showTimes = State(initialValue: !initialWeek.earlyStarts.isEmpty || !initialWeek.lateFinishes.isEmpty)
    }

    var body: some View {
        NavigationStack {
            yourWeek
                .navigationDestination(isPresented: $onPlan) { nextWeek }
        }
    }

    // MARK: Screen 1 · Your week

    private var yourWeek: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                weightHero
                Text(CheckInFormat.weekLine(programme: programme, profile: profile, history: history,
                                            steps: BodyStats.shared.steps, monday: monday, calendar: calendar))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("checkin.weekLine")
                question("Energy") {
                    Picker("Energy", selection: $checkIn.energy) {
                        ForEach(CheckInAnswers.Energy.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("checkin.energy")
                }
                question("Sleep") {
                    Picker("Sleep", selection: $checkIn.sleep) {
                        ForEach(CheckInAnswers.Sleep.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("checkin.sleep")
                }
                question("Any pain") {
                    Picker("Any pain", selection: $hasPain) {
                        Text("None").tag(false)
                        Text("Yes").tag(true)
                    }
                    .accessibilityIdentifier("checkin.pain")
                }
                if hasPain { painAreas }
            }
            .pickerStyle(.segmented)
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Your week")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("checkin.week")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Later") { dismiss() }.accessibilityIdentifier("checkin.cancel")
            }
        }
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button("Next") { onPlan = true }
                    .buttonStyle(PrimaryActionStyle())
                    .accessibilityIdentifier("checkin.next")
            }
        }
        .onChange(of: hasPain) { _, yes in if !yes { checkIn.pain = [] } }
    }

    private var weightHero: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if let weight = BodyStats.shared.weight {
                Text("\(WeightTrend.oneDecimal(weight.averageKg)) kg")
                    .font(.coachNumber(48))
                let change = WeightTrend.changeSinceStart(samples: BodyStats.shared.weightHistory,
                                                          start: profile.programme.startDate,
                                                          now: AppClock.now(), calendar: calendar)
                Text(WeightTrend.heroSubline(changeSinceStart: change))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No weight trend yet").font(.headline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("checkin.weight")
    }

    private func question<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    /// Two rows of three, at least 44 pt each; no typing (Advisor 2).
    private var painAreas: some View {
        let areas = CheckInAnswers.PainArea.allCases
        return VStack(spacing: 8) {
            ForEach([Array(areas.prefix(3)), Array(areas.suffix(3))], id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { area in painButton(area) }
                }
            }
        }
    }

    private func painButton(_ area: CheckInAnswers.PainArea) -> some View {
        let on = checkIn.pain.contains(area)
        return Button {
            if on { checkIn.pain.remove(area) } else { checkIn.pain.insert(area) }
        } label: {
            Text(area.rawValue)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(on ? Color.onGo : Color.primary)
                .background(on ? Color.go : Color.surface, in: .rect(cornerRadius: Radius.pill))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("checkin.painArea.\(area.rawValue.lowercased())")
    }

    // MARK: Screen 2 · Next week

    private var nextWeek: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Office days, week of \(monday.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.headline)
                OfficeWeekEditor(answers: $week, showTimes: $showTimes,
                                 workStart: profile.schedule.workStart, workEnd: profile.schedule.workEnd)
                ChangesCard(changes: changes)
                if let line = CheckInFormat.sessionsLine(programme: programme, profile: profile,
                                                         monday: monday, calendar: calendar) {
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("checkin.sessions")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Next week")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("checkin.plan")
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button("Looks good") {
                    onDone(checkIn, OfficeWeekEditor.cleaned(week, workStart: profile.schedule.workStart,
                                                             workEnd: profile.schedule.workEnd))
                    dismiss()
                }
                .buttonStyle(PrimaryActionStyle())
                .accessibilityIdentifier("checkin.done")
            }
        }
    }
}

/// Check-in text, kept out of the view.
enum CheckInFormat {
    /// "4 of 4 sessions · 8,900 steps a day": information only (Advisor 6).
    /// The week just ending is the one before `monday`.
    static func weekLine(programme: Programme, profile: Profile, history: [SessionLog], steps: StepsSummary?,
                         monday: Date, calendar: Calendar) -> String {
        var parts: [String] = []
        if let start = profile.programme.startDate,
           let lastMonday = calendar.date(byAdding: .day, value: -7, to: monday) {
            let planned = CoachSummary.plannedSessions(programme: programme, start: start, from: lastMonday,
                                                       to: monday, calendar: calendar)
            let done = SessionLog.sessionIDs(in: history, weekOf: lastMonday, calendar: calendar).count
            if planned > 0 { parts.append("\(min(done, planned)) of \(planned) sessions") }
        }
        if let average = steps?.sevenDayAverage { parts.append("\(average.formatted()) steps a day") }
        return parts.isEmpty ? "A quiet week" : parts.joined(separator: " · ")
    }

    /// "Upper A · Easy run · Lower A · Intervals": next week's sessions in order.
    static func sessionsLine(programme: Programme, profile: Profile, monday: Date, calendar: Calendar) -> String? {
        guard let start = profile.programme.startDate else { return nil }
        let names: [String] = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday),
                  case let .session(_, session) = programme.plannedDay(on: day, start: start, calendar: calendar).entry
            else { return nil }
            return session.name
        }
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }
}
