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
    var onDone: (CheckIn, WeekAnswers) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var checkIn = CheckIn(date: AppClock.now())
    @State private var hasPain = false
    @State private var week: WeekAnswers
    @State private var showTimes: Bool
    @State private var onPlan = false

    private let calendar = Calendar.coach

    init(monday: Date, programme: Programme, profile: Profile, history: [SessionLog], changes: [CoachChange],
         initialWeek: WeekAnswers, onDone: @escaping (CheckIn, WeekAnswers) -> Void) {
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

    /// The week just ending, from the core (sessions done of planned).
    private var prefill: CheckInPrefill {
        CheckInPrefill.make(now: AppClock.now(), programme: programme, profile: profile, history: history,
                            weights: BodyStats.shared.weightHistory, steps: [], calendar: calendar)
    }

    // MARK: Screen 1 · Your week

    private var yourWeek: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                weightHero
                Text(CheckInFormat.weekLine(prefill, steps: BodyStats.shared.steps))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("checkin.weekLine")
                question("Energy") {
                    Picker("Energy", selection: $checkIn.energy) {
                        ForEach(CheckIn.Energy.allCases, id: \.self) { Text(CheckInFormat.label($0)).tag($0) }
                    }
                    .accessibilityIdentifier("checkin.energy")
                }
                question("Sleep") {
                    Picker("Sleep", selection: $checkIn.sleep) {
                        ForEach(CheckInFormat.sleepChoices, id: \.self) { Text(CheckInFormat.label($0)).tag($0) }
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
        let areas = PainArea.allCases
        return VStack(spacing: 8) {
            ForEach([Array(areas.prefix(3)), Array(areas.suffix(3))], id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { area in painButton(area) }
                }
            }
        }
    }

    private func painButton(_ area: PainArea) -> some View {
        let on = checkIn.pain.contains(area)
        return Button {
            if on { checkIn.pain.removeAll { $0 == area } } else { checkIn.pain.append(area) }
        } label: {
            Text(area.rawValue.capitalized)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(on ? Color.onGo : Color.primary)
                .background(on ? Color.go : Color.surface, in: .rect(cornerRadius: Radius.pill))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("checkin.painArea.\(area.rawValue)")
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
                // N1 (Advisor c): knee or back pain turns next week's run-walk into a brisk walk.
                if let line = CheckInFormat.runWalkLine(programme: programme, profile: profile, monday: monday,
                                                        pain: Set(checkIn.pain), calendar: calendar) {
                    Label(line, systemImage: "figure.walk")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("checkin.runWalkLine")
                }
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
                    var answered = checkIn
                    answered.date = AppClock.now()
                    // Keep the areas in the order the screen shows them.
                    answered.pain = PainArea.allCases.filter { checkIn.pain.contains($0) }
                    onDone(answered, OfficeWeekEditor.cleaned(week, workStart: profile.schedule.workStart,
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
    /// Steps come from the phone's 7-day summary; the prefill has no daily counts here.
    static func weekLine(_ prefill: CheckInPrefill, steps: StepsSummary?) -> String {
        var parts: [String] = []
        if prefill.sessionsPlanned > 0 {
            parts.append("\(min(prefill.sessionsDone, prefill.sessionsPlanned)) of \(prefill.sessionsPlanned) sessions")
        }
        if let average = steps?.sevenDayAverage { parts.append("\(average.formatted()) steps a day") }
        return parts.isEmpty ? "A quiet week" : parts.joined(separator: " · ")
    }

    /// The run-walk line for next week's first run-walk, or nil when it runs as planned.
    static func runWalkLine(programme: Programme, profile: Profile, monday: Date, pain: Set<PainArea>,
                            calendar: Calendar) -> String? {
        guard PainSwaps.walksInsteadOfRunning(pain), let start = profile.programme.startDate else { return nil }
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { continue }
            let planned = programme.plannedDay(on: day, start: start, calendar: calendar)
            guard let week = planned.week, case let .session(id, .runWalk(run)) = planned.entry,
                  let plan = RunWalkPlan.make(sessionID: id, session: run, week: week, painAreas: pain)
            else { continue }
            return PainSwaps.runWalkLine(areas: pain, minutes: max(1, plan.totalSeconds / 60))
        }
        return nil
    }

    /// Sleep offers Fine and Poor (Advisor A1); Good stays in the core for later.
    static let sleepChoices: [CheckIn.Sleep] = [.fine, .poor]

    static func label(_ energy: CheckIn.Energy) -> String {
        switch energy { case .good: "Good"; case .ok: "OK"; case .low: "Low" }
    }

    static func label(_ sleep: CheckIn.Sleep) -> String {
        switch sleep { case .good: "Good"; case .fine: "Fine"; case .poor: "Poor" }
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
