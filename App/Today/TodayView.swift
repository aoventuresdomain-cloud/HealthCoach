import CoachCore
import SwiftData
import SwiftUI

/// Today (board M1-05, design screens 1–2): what's next and when, one card,
/// a short timeline, one button. Nothing asks anything except the optional
/// "Still sore?" row, which defaults to Fine.
struct TodayView: View {
    let content: ContentLibrary
    let programme: Programme
    let profile: Profile
    /// Starts the session with the recovery answer (Fine unless changed).
    var onStart: (DayPlan.SessionSlot, Int, RecoveryCheck) -> Void

    @State private var dayOffset = 0
    @State private var recovery = RecoveryCheck.fine
    @State private var alarmStatus = AlarmReconcileStatus.notYetRun
    /// The Monday the Sunday prompt sheet is open for; nil when closed.
    @State private var promptWeek: PromptWeek?
    /// Bumped after the prompt saves, so the "Plan next week" card re-reads the store.
    @State private var answersVersion = 0
    @Environment(\.modelContext) private var context

    private let calendar = Calendar.coach

    var body: some View {
        let now = AppClock.now()
        let date = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
        let _ = answersVersion
        // M2-05: the same plan as the alarms, with the Sunday prompt's answers
        // and the reduced week's dropped session. E13: an unlogged session whose
        // slot has passed moves (logged this week = done).
        let history = (try? SessionLogStore(context: context).all()) ?? []
        let done = SessionLog.sessionIDs(in: history, weekOf: now, calendar: calendar)
        let plan = DayPlan.make(for: date, programme: programme, profile: profile,
                                answers: { WeekAnswersStore.shared.answers(weekStarting: $0, calendar: calendar) },
                                dropping: Set(programme.droppedSessions(history: history)),
                                now: now, completed: done, calendar: calendar)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(date: date, plan: plan)
                if let notice = TodayFormat.storeNotice(AppStore.recovery) {
                    Label(notice, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("today.storeNotice")
                }
                if dayOffset == 0, let banner = alarmBanner {
                    banner
                }
                if dayOffset == 0, let swap = weatherSwap {
                    weatherCard(swap)
                }
                if dayOffset == 0, let weight = BodyStats.shared.weight {
                    // M2-04: the 7-day trend from the scale, read from Health.
                    Label(weight.summary, systemImage: "scalemass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("today.weight")
                }
                if dayOffset == 0, let monday = promptDue(now: now) {
                    planWeekCard(monday)
                }
                if let plan {
                    card(plan)
                    // QA-20: the session row follows a weather swap, like the header.
                    TimelineCard(items: plan.swapped(by: dayOffset == 0 ? weatherSwap : nil, programme: programme).timeline, now: dayOffset == 0 ? TodayFormat.timeOfDay(now, calendar) : nil)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { actions(plan) }
        .toolbar {
            if profile.programme.startDate != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        promptWeek = PromptWeek(monday: SundayPrompt.monday(for: AppClock.now(), calendar: calendar))
                    } label: { Image(systemName: "calendar") }
                        .accessibilityLabel("Plan the week")
                        .accessibilityIdentifier("today.planWeekToolbar")
                }
            }
            if SpikeTests.isEnabled {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SpikeTestsView() } label: { Image(systemName: "wrench.adjustable") }
                        .accessibilityLabel("Spike tests")
                        .accessibilityIdentifier("home.spikeTests")
                }
            }
        }
        .task { alarmStatus = await AlarmKitSpike.shared.reconcileStatus() }
        .sheet(item: $promptWeek) { week in
            SundayPromptView(monday: week.monday,
                             initial: WeekAnswersStore.shared.answers(weekStarting: week.monday, calendar: calendar),
                             workStart: profile.schedule.workStart, workEnd: profile.schedule.workEnd) { answers in
                save(answers, weekStarting: week.monday)
            }
        }
    }

    // MARK: Weather (M2-03)

    /// Today's swap from the morning forecast; only ever for today.
    private var weatherSwap: WeatherSwap? {
        dayOffset == 0 ? MorningWeather.shared.decision?.swap : nil
    }

    /// The session to show and start: the indoor one when today's run is swapped.
    private func todaySlot(_ plan: DayPlan) -> DayPlan.SessionSlot? {
        guard let planned = plan.session else { return nil }
        guard let swap = weatherSwap else { return planned }
        return planned.swapped(by: swap, programme: programme) ?? planned
    }

    private func weatherCard(_ swap: WeatherSwap) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cloud.rain.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text(swap.note(programme: programme) + ".")
                    .accessibilityIdentifier("today.weatherSwap")
                Button("I'll run anyway") { MorningWeather.shared.runAnyway(calendar: calendar) }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("today.runAnyway")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.surface, in: .rect(cornerRadius: Radius.card))
    }

    // MARK: Sunday prompt

    private struct PromptWeek: Identifiable {
        let monday: Date
        var id: Date { monday }
    }

    /// Next week's Monday from Saturday until it is answered; nil otherwise.
    private func promptDue(now: Date) -> Date? {
        _ = answersVersion
        guard profile.programme.startDate != nil, SundayPrompt.isDue(on: now, calendar: calendar) else { return nil }
        let monday = SundayPrompt.monday(for: now, calendar: calendar)
        return WeekAnswersStore.shared.hasAnswers(weekStarting: monday, calendar: calendar) ? nil : monday
    }

    private func planWeekCard(_ monday: Date) -> some View {
        Button {
            promptWeek = PromptWeek(monday: monday)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan next week").font(.headline)
                    Text("Which days are you in the office? 20 seconds.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today.planWeek")
    }

    /// Saves the answers, then re-plans alarms and notifications at once
    /// (plan §4.1: alarms are reconciled after the Sunday prompt).
    private func save(_ answers: WeekAnswers, weekStarting monday: Date) {
        WeekAnswersStore.shared.save(answers, weekStarting: monday, calendar: calendar)
        answersVersion += 1
        let history = (try? SessionLogStore(context: context).all()) ?? []
        let profile = profile
        Task {
            if WakeAlarms.shared.isActive(profile: profile) {
                await WakeAlarms.shared.reconcile(profile: profile, history: history)
            }
            await CoachNotifier.shared.reschedule(profile: profile, history: history)
            await MorningWeather.shared.check(profile: profile)
        }
    }

    // MARK: Header

    private func header(date: Date, plan: DayPlan?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(TodayFormat.dateLine(date, week: plan?.planned.week, programme: programme, calendar: calendar))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityIdentifier("today.date")
            Text(title(plan, date: date))
                .font(.largeTitle.bold())
                .accessibilityIdentifier("today.title")
            if LaunchOptions.current.isUITest {
                UITestStatus()
            }
        }
    }

    private func title(_ plan: DayPlan?, date: Date) -> String {
        guard let plan else { return "Today" }
        if let slot = todaySlot(plan) { return "\(slot.name) at \(slot.start)" }
        switch plan.planned.entry {
        case let .fixed(event): return event.time == "evening" ? "\(event.name) tonight" : event.name
        case .beforeStart:
            let start = profile.programme.startDate ?? date
            return "\(programme.name) starts \(start.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))"
        case .afterEnd: return "Phase \(programme.phase) done"
        case .rest, .session: return "Rest day"
        }
    }

    // MARK: Card

    @ViewBuilder
    private func card(_ plan: DayPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let slot = todaySlot(plan), let week = plan.planned.week {
                Text(slot.name).font(.title2.bold())
                let summary = SessionSummary(slot: slot, week: week, content: content)
                if let subtitle = summary.subtitle {
                    Text(subtitle).foregroundStyle(.secondary)
                }
                // UI-4: one meta line instead of stacked chips.
                if !summary.chips.isEmpty {
                    Text(summary.chips.joined(separator: " · "))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if case .strength = slot.session, dayOffset == 0 {
                    Divider()
                    // UI-4: label on its own line, then a full-width, large picker. Fine stays pre-selected.
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("Still sore from last time?").foregroundStyle(.secondary)
                        Picker("Still sore from last time?", selection: $recovery) {
                            Text("Fine").tag(RecoveryCheck.fine)
                            Text("Sore").tag(RecoveryCheck.sore)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("today.recovery")
                    }
                }
            } else {
                Text(noSessionTitle(plan)).font(.title2.bold())
                Text(noSessionDetail(plan)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.card")
    }

    private func noSessionTitle(_ plan: DayPlan) -> String {
        switch plan.planned.entry {
        case .beforeStart: "Week 1 hasn't started"
        case .afterEnd: "Checkpoint time"
        default: dayOffset == 0 ? "No session today" : "No session"
        }
    }

    private func noSessionDetail(_ plan: DayPlan) -> String {
        switch plan.planned.entry {
        case let .fixed(event): event.note ?? event.name
        case .beforeStart: "Keep going with the paper plan until then."
        case .afterEnd: "Phase \(programme.phase) is done. Share the summary with Claude for the checkpoint review."
        default: "Rest. A walk is always welcome."
        }
    }

    // MARK: Banner

    /// QA-1: once the planner owns the alarms, Today reads its coverage, and
    /// zero upcoming alarms is always a warning, never "all set".
    private var alarmBanner: AnyView? {
        let wake = WakeAlarms.shared
        if wake.isActive(profile: profile) {
            switch wake.coverage {
            case let .reSet(missing, _, _)?:
                return AnyView(Banner(strong: "\(missing) \(missing == 1 ? "alarm was" : "alarms were") missing.",
                                      rest: "They're set again, so nothing to do."))
            case let coverage? where coverage.needsWarning:
                return AnyView(Banner(strong: "No alarms set.",
                                      rest: wake.lastError ?? "Allow alarms in Settings so the coach can wake you.",
                                      identifier: "today.alarmWarning",
                                      settingsLink: wake.lastError == nil, warns: true))
            default:
                return nil
            }
        }
        switch alarmStatus {
        case let .reSet(missing, _):
            return AnyView(Banner(strong: "\(missing) \(missing == 1 ? "alarm was" : "alarms were") missing.",
                                  rest: "They're set again, so nothing to do."))
        case let .failed(reason):
            return AnyView(Banner(strong: "Alarm check failed.", rest: reason))
        case .notYetRun, .allSet:
            return nil
        }
    }

    // MARK: Actions

    @ViewBuilder
    private func actions(_ plan: DayPlan?) -> some View {
        ActionBar {
            if dayOffset == 0, let plan, let slot = todaySlot(plan), let week = plan.planned.week {
                Button("Start \(slot.name)") { onStart(slot, week, recovery) }
                    .buttonStyle(PrimaryActionStyle())
                    .accessibilityIdentifier("today.start")
            } else if dayOffset == 0 {
                Button("See tomorrow") { dayOffset = 1 }
                    .buttonStyle(PlainGreyLargeStyle())
                    .accessibilityIdentifier("today.seeTomorrow")
            } else {
                Button("Back to today") { dayOffset = 0 }
                    .buttonStyle(PlainGreyLargeStyle())
                    .accessibilityIdentifier("today.backToToday")
            }
        }
    }
}

/// The grey, full-height button for days with nothing to start.
struct PlainGreyLargeStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 76)
            .foregroundStyle(.primary)
            .background(Color(.secondarySystemGroupedBackground).opacity(configuration.isPressed ? 0.6 : 1), in: .rect(cornerRadius: 22))
            .contentShape(.rect)
    }
}

private struct Banner: View {
    let strong: String
    let rest: String
    var identifier = "today.alarmBanner"
    /// Adds "Open Settings" for a fix only the owner can make.
    var settingsLink = false
    /// UI-2: only the zero-alarms warning buzzes; "missing, now set" is reassurance.
    var warns = false
    @State private var shown = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(Text(strong).bold().foregroundStyle(.orange)) \(rest)")
                    .accessibilityIdentifier(identifier)
                if settingsLink, let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("today.openSettings")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.15), in: .rect(cornerRadius: 20))
        .onAppear { shown = true }
        .sensoryFeedback(trigger: shown) { _, new in warns && new ? .warning : nil }
    }
}

struct TimelineCard: View {
    let items: [DayPlan.TimelineItem]
    /// nil when showing another day: nothing is past or current.
    let now: TimeOfDay?

    var body: some View {
        let current = now.flatMap { now in items.lastIndex { ($0.time ?? .init(hour: 23, minute: 59)) <= now } }
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isPast = current.map { index < $0 } ?? false
                let isCurrent = current == index
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(item.time?.description ?? "–")
                        .font(.body.monospacedDigit())
                        .frame(width: 56, alignment: .leading)
                    Circle()
                        .fill(isCurrent ? Color.green : Color(.systemGray))
                        .frame(width: isCurrent ? 12 : 9, height: isCurrent ? 12 : 9)
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.headline)
                        if let detail = item.detail {
                            Text(detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .opacity(isPast ? 0.45 : 1)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("today.timeline.\(item.id)")
                if index < items.count - 1 { Divider().padding(.leading, 16) }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}

/// What the session card says, all from the programme and exercise data.
struct SessionSummary {
    let subtitle: String?
    let chips: [String]

    init(slot: DayPlan.SessionSlot, week: Int, content: ContentLibrary) {
        var chips: [String] = []
        if let minutes = slot.minutes { chips.append("\(minutes) min") }
        switch slot.session {
        case let .strength(session):
            let items = session.blocks.flatMap(\.items).filter { ($0.sets[safe: week - 1] ?? 0) > 0 }
            let exercises = items.compactMap { content.exercises.exercise($0.exercise) }
            chips.append("\(items.count) exercises")
            let kit = TodayFormat.kit(exercises.flatMap(\.equipment))
            if !kit.isEmpty { chips.append(kit) }
            subtitle = TodayFormat.groups(exercises.map(\.group))
        case let .runWalk(run):
            if let w = run.weeks.first(where: { $0.week == week }) {
                chips.append("\(w.intervals.repeats) × \(TodayFormat.seconds(w.intervals.jogSeconds)) jog")
            }
            subtitle = run.note
        case let .walk(walk):
            subtitle = walk.note
        case let .circuit(circuit):
            subtitle = circuit.note
        }
        self.chips = chips
    }
}

enum TodayFormat {
    /// One line when the store had to recover on launch (Planner, PR #27).
    static func storeNotice(_ recovery: StoreRecovery?) -> String? {
        switch recovery {
        case .startedFresh: "We couldn't open your saved data, so we kept a copy and started fresh."
        case .memoryOnly: "Your data can't be saved right now. Restart the phone if this stays."
        case nil: nil
        }
    }

    static func dateLine(_ date: Date, week: Int?, programme: Programme, calendar: Calendar) -> String {
        let day = date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        guard let week else { return day }
        return "\(day) · Week \(week) of Phase \(programme.phase)"
    }

    static func timeOfDay(_ date: Date, _ calendar: Calendar) -> TimeOfDay {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    static func groups(_ groups: [Exercise.Group]) -> String? {
        let order: [(Exercise.Group, String)] = [(.push, "chest"), (.pull, "back"), (.shoulders, "shoulders"), (.arms, "arms"), (.legs, "legs"), (.core, "core")]
        let words = order.filter { groups.contains($0.0) }.map(\.1)
        guard let first = words.first else { return nil }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + words.dropFirst()).joined(separator: ", ")
    }

    static func kit(_ equipment: [Exercise.Equipment]) -> String {
        let order: [(Exercise.Equipment, String)] = [(.dumbbells, "Dumbbells"), (.bench, "bench"), (.pullUpBar, "bar"), (.band, "band")]
        let words = order.filter { equipment.contains($0.0) }.map(\.1)
        guard let first = words.first else { return "" }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + words.dropFirst()).joined(separator: " · ")
    }

    static func seconds(_ seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60) min" : seconds < 60 ? "\(seconds) s" : "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
