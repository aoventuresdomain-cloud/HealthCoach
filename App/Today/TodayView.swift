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
    /// C2: the coach line's tap; Root switches to Progress with Ask in view.
    var onAskCoach: () -> Void = {}
    /// N4 via N9a: the office lunch walk answered from the lunch card.
    var onLunchWalk: (Int) -> Void = { _ in }

    @State private var dayOffset = 0
    @State private var recovery = RecoveryCheck.fine
    @State private var alarmStatus = AlarmReconcileStatus.notYetRun
    /// The Monday the Sunday prompt sheet is open for; nil when closed.
    @State private var promptWeek: PromptWeek?
    /// Tomorrow's date while the "Tomorrow changed" sheet is open (M2-06).
    @State private var changingTomorrow: PromptWeek?
    @State private var showSpikeTests = false
    /// N9a: the lunch card, opened from the timeline's lunch row.
    @State private var showLunch = false
    /// N9a: the day's office lunch, planned once per day and answer (`lunchKey`),
    /// not on every render: the meal plan replays the coach, and Today redraws
    /// while a session plays.
    @State private var lunch = TodayLunch.none
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
        // The phase in force on the day shown, so "See tomorrow" before a new phase shows the new one.
        let dayProgramme = content.programme(for: profile, on: date, calendar: calendar) ?? programme
        let plan = DayPlan.make(for: date, programme: dayProgramme, profile: profile,
                                answers: { WeekAnswersStore.shared.answers(weekStarting: $0, calendar: calendar) },
                                dropping: CoachBlockStore().droppedSessions(programme: dayProgramme, history: history,
                                                                            profile: profile, on: date, calendar: calendar),
                                now: now, completed: done, calendar: calendar)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(date: date, plan: plan)
                if dayOffset == 0, let line = coachLine(history: history, now: now) {
                    // C2: one line, only when the coach is needed (stall, checkpoint, dumbbell limit).
                    Button(action: onAskCoach) {
                        Label(line, systemImage: "flag")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.caution)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens Progress, with Ask the coach now")
                    .accessibilityIdentifier("today.coachLine")
                }
                if let notice = TodayFormat.storeNotice(AppStore.recovery) {
                    Label(notice, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("today.storeNotice")
                }
                if dayOffset == 0, let banner = alarmBanner {
                    banner
                }
                // UI-12: the weight line moved to Progress (progress.weight); the
                // weather swap is the card's meta line plus "I'll run anyway" below.
                if dayOffset == 0, let monday = promptDue(now: now) {
                    planWeekCard(monday)
                }
                if let plan {
                    // UI-12: no card on a no-session day; the title and timeline say it.
                    if todaySlot(plan) != nil, plan.planned.week != nil {
                        card(plan)
                    }
                    // QA-20: the session row follows a weather swap, like the header.
                    // N9a: the office lunch order on office days, the same order Meals plans.
                    let shown = plan.swapped(by: dayOffset == 0 ? weatherSwap : nil, programme: programme)
                        .withOfficeLunch(lunch.meals, orders: lunch.orders)
                    // QA-28: the current row is the first one not over yet (CoachCore).
                    TimelineCard(items: shown.timeline,
                                 current: dayOffset == 0 ? shown.timelineProgress(at: TodayFormat.timeOfDay(now, calendar)) : nil,
                                 onLunch: { showLunch = true })
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { actions(plan) }
        .toolbar {
            // UI-12: one ⋯ menu instead of separate chrome icons.
            if profile.programme.startDate != nil || SpikeTests.showsLink {
                ToolbarItem(placement: .topBarTrailing) { moreMenu }
            }
        }
        .navigationDestination(isPresented: $showSpikeTests) { SpikeTestsView() }
        .task { alarmStatus = await AlarmKitSpike.shared.reconcileStatus() }
        // N9: the Sunday prompt notification (W1) opens the check-in for next week.
        .task(id: NotificationTaps.shared.pending) {
            guard NotificationTaps.shared.pending == .sundayPrompt else { return }
            NotificationTaps.shared.pending = nil
            if profile.programme.startDate != nil {
                promptWeek = PromptWeek(monday: SundayPrompt.monday(for: AppClock.now(), calendar: calendar))
            }
        }
        .task(id: lunchKey(date)) { lunch = officeLunch(on: date, now: now) }
        .sheet(isPresented: $showLunch) {
            TodayLunchCard(meals: lunch.meals, orders: lunch.orders, food: profile.food,
                           defaultWalk: content.lunchOrders.origin.maxWalkMinutes, onWalk: onLunchWalk)
        }
        .sheet(item: $promptWeek) { week in
            SundayPromptView(monday: week.monday,
                             initial: WeekAnswersStore.shared.answers(weekStarting: week.monday, calendar: calendar),
                             workStart: profile.schedule.workStart, workEnd: profile.schedule.workEnd) { answers in
                save(answers, weekStarting: week.monday)
            }
        }
        .sheet(item: $changingTomorrow) { tomorrow in
            let monday = AlarmSchedule.mondayOf(tomorrow.monday, calendar: calendar)
            TomorrowChangedView(date: tomorrow.monday,
                                day: Weekday(calendarWeekday: calendar.component(.weekday, from: tomorrow.monday)),
                                week: WeekAnswersStore.shared.answers(weekStarting: monday, calendar: calendar),
                                workStart: profile.schedule.workStart, workEnd: profile.schedule.workEnd) { answers in
                save(answers, weekStarting: monday)
                // Show the re-planned tomorrow straight away; "Back to today" returns.
                dayOffset = 1
            }
        }
    }

    // MARK: Office lunch (N9a)

    /// Changes when the day, the N4/N3 answers or the week's office days do.
    private func lunchKey(_ date: Date) -> String {
        let day = calendar.startOfDay(for: date).timeIntervalSinceReferenceDate
        let food = profile.food
        return "\(day)|\(food.officeLunchMaxWalkMinutes ?? -1)|\(food.dislikes)|\(answersVersion)"
    }

    /// The meal plan's lunch for `date`, planned only on an office day.
    private func officeLunch(on date: Date, now: Date) -> TodayLunch {
        let monday = AlarmSchedule.mondayOf(date, calendar: calendar)
        let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: date))
        guard WeekAnswersStore.shared.answers(weekStarting: monday, calendar: calendar).officeDays.contains(weekday)
        else { return .none }
        let plan = WeekMeals.plan(for: date, now: now, content: content, profile: profile, context: context,
                                  calendar: calendar)
        return TodayLunch(meals: plan.day(date, calendar: calendar), orders: profile.food.lunchOrders(content.lunchOrders))
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

    // MARK: ⋯ menu (UI-12)

    /// Plan week, Tomorrow changed (M2-06) and, under -spikeAlarms only, Spike tests (M0-11b).
    private var moreMenu: some View {
        Menu {
            if profile.programme.startDate != nil {
                Button {
                    promptWeek = PromptWeek(monday: SundayPrompt.monday(for: AppClock.now(), calendar: calendar))
                } label: { Label("Plan the week", systemImage: "calendar") }
                    .accessibilityIdentifier("today.planWeekToolbar")
            }
            if let tomorrow = changeableTomorrow {
                Button {
                    changingTomorrow = PromptWeek(monday: tomorrow)
                } label: { Label("Tomorrow changed", systemImage: "calendar.badge.clock") }
                    .accessibilityIdentifier("today.tomorrowChanged")
            }
            if SpikeTests.showsLink {
                Button {
                    showSpikeTests = true
                } label: { Label("Spike tests", systemImage: "wrench.adjustable") }
                    .accessibilityIdentifier("home.spikeTests")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("More")
        .accessibilityIdentifier("today.more")
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
            // UI-12: one line.
            HStack(spacing: 12) {
                Text("Plan next week").font(.headline)
                Text("· 20 s").foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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

    // MARK: Coach line (C2)

    private func coachLine(history: [SessionLog], now: Date) -> String? {
        CoachReview.make(programme: programme, profile: profile, history: history,
                         weights: BodyStats.shared.weightHistory, blocks: CoachBlockStore().all,
                         now: now, calendar: calendar)?
            .todayLine { content.exercises.exercise($0)?.name ?? $0 }
    }

    // MARK: Header

    private func header(date: Date, plan: DayPlan?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(TodayFormat.dateLine(date, week: plan?.planned.week, programme: programme, calendar: calendar))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
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
        // UI-12: the title already names the session, so the card is the meta
        // line plus the Fine / Still sore picker (and the weather swap, if any).
        VStack(alignment: .leading, spacing: 12) {
            if let slot = todaySlot(plan), let week = plan.planned.week {
                let summary = SessionSummary(slot: slot, week: week, content: content)
                if let swap = weatherSwap {
                    Text((summary.chips.prefix(1) + ["rain swapped your run"]).joined(separator: " · "))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(swap.note(programme: programme) + ". Rain swapped your run.")
                        .accessibilityIdentifier("today.weatherSwap")
                } else if !summary.chips.isEmpty {
                    Text(summary.chips.joined(separator: " · "))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("today.meta")
                }
                if case .strength = slot.session, dayOffset == 0 {
                    // Fine stays pre-selected; VoiceOver still reads the full question.
                    Picker("Still sore from last time?", selection: $recovery) {
                        Text("Fine").tag(RecoveryCheck.fine)
                        Text("Still sore").tag(RecoveryCheck.sore)
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Still sore from last time?")
                    .accessibilityIdentifier("today.recovery")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.card")
    }

    // MARK: Banner

    /// QA-1: once the planner owns the alarms, Today reads its coverage, and
    /// zero upcoming alarms is always a warning, never "all set".
    private var alarmBanner: AnyView? {
        let wake = WakeAlarms.shared
        if wake.isActive(profile: profile) {
            // UI-12: "N alarms were missing, set again" is cut (it needs nothing);
            // the re-set still shows in debug.launch (alarms=). Warnings stay (QA-1).
            switch wake.coverage {
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
        case let .failed(reason):
            return AnyView(Banner(strong: "Alarm check failed.", rest: reason))
        case .notYetRun, .allSet, .reSet:
            return nil
        }
    }

    // MARK: Tomorrow changed (M2-06)

    /// Tomorrow, when it is a workday inside a planned programme; else nil
    /// (weekends have no office or start times to change).
    private var changeableTomorrow: Date? {
        guard profile.programme.startDate != nil,
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: AppClock.now())) else { return nil }
        let day = Weekday(calendarWeekday: calendar.component(.weekday, from: tomorrow))
        return SundayPromptView.workdays.contains(day) ? tomorrow : nil
    }

    // MARK: Actions

    @ViewBuilder
    private func actions(_ plan: DayPlan?) -> some View {
        ActionBar {
            // UI-12: the weather swap's "run anyway" is the one secondary.
            if dayOffset == 0, weatherSwap != nil {
                Button("I'll run anyway") { MorningWeather.shared.runAnyway(calendar: calendar) }
                    .buttonStyle(SecondaryActionStyle())
                    .accessibilityIdentifier("today.runAnyway")
            }
        } primary: {
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

/// N9a: the day's meals and the orders within the owner's walk.
struct TodayLunch {
    var meals: MealDay?
    var orders: [LunchOrder]
    static let none = TodayLunch(meals: nil, orders: [])
}

struct TimelineCard: View {
    let items: [DayPlan.TimelineItem]
    /// The current row from `DayPlan.timelineProgress(at:)`; rows before it are past.
    /// nil when showing another day: nothing is past or current.
    let current: Int?
    /// N9a: the lunch row opens the lunch card; the other rows aren't buttons.
    var onLunch: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if item.kind == .lunch {
                    Button(action: onLunch) { row(item, index: index) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens today's lunch order")
                        .accessibilityIdentifier("today.timeline.\(item.id)")
                } else {
                    row(item, index: index)
                        .accessibilityIdentifier("today.timeline.\(item.id)")
                }
                if index < items.count - 1 { Divider().padding(.leading, 16) }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    private func row(_ item: DayPlan.TimelineItem, index: Int) -> some View {
        let isPast = current.map { index < $0 } ?? false
        let isCurrent = current == index
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(item.time?.description ?? "–")
                .font(.body.monospacedDigit())
                .frame(width: 56, alignment: .leading)
            Circle()
                .fill(isCurrent ? Color.green : Color(.systemGray))
                .frame(width: isCurrent ? 12 : 9, height: isCurrent ? 12 : 9)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.headline)
                // UI-12: "Alarm" under Wake and "Done by" under the session repeat what's visible.
                if let detail = item.detail, item.kind != .wake, item.kind != .session {
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if item.kind == .lunch {
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .opacity(isPast ? 0.45 : 1)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
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
            // QA-33: the card's note was cut (UI-12), so "optional" is said once, in the meta line.
            if walk.optional { chips.append("optional") }
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
        // UI-12: "Mon 23 Nov · Week 1"; the phase is on Progress.
        let day = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        guard let week else { return day }
        return "\(day) · Week \(week)"
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
