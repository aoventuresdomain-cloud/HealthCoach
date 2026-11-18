import Charts
import CoachCore
import SwiftData
import SwiftUI

/// Progress (board M4-03, plan §4.6): the weight trend, strength by lift,
/// photos every 2 weeks, and "Ask the coach now". The ghost outline and
/// the mood check are deferred (re-plan, 17 Nov).
/// No streaks or badges (design B10).
struct ProgressScreen: View {
    let content: ContentLibrary
    let programme: Programme
    let profile: Profile
    /// C2: set by Today's coach line; scrolls "Ask the coach now" into view, then clears.
    @Binding var showAskCoach: Bool

    @Environment(\.modelContext) private var context
    @State private var photoDay = false
    /// The summary shown in full before sharing, when it carries the waist.
    @State private var previewSummary: String?
    @State private var version = 0
    /// Bumped when an import result appears, to scroll it clear of the tab bar (QA-32).
    @State private var importResults = 0

    private let calendar = Calendar.coach
    private var store: ProgressStore { .shared }
    private static let importRow = "coach.importRow"
    private static let askRow = "coach.askRow"

    /// "Steps: 6,240 today · 8,100 a day last week" (the average only once there is one).
    static func stepsLine(_ steps: StepsSummary) -> String {
        var line = "Steps: \(steps.today.formatted()) today"
        if let average = steps.sevenDayAverage { line += " · \(average.formatted()) a day last week" }
        return line
    }

    var body: some View {
        let _ = version
        let now = AppClock.now()
        let history = (try? SessionLogStore(context: context).all()) ?? []
        let sets = store.sets(calendar: calendar)
        ScrollViewReader { proxy in
        List {
            // N2: what changed in the last 7 days, and why; no card when nothing did.
            let changes = CoachChanges.make(programme: programme, profile: profile, history: history,
                                            weights: BodyStats.shared.weightHistory, blocks: CoachBlockStore().all,
                                            checkIns: CheckInStore.shared.all, exercises: content.exercises,
                                            now: now, name: { content.exercises.exercise($0)?.name ?? $0 },
                                            calendar: calendar)
            if !changes.isEmpty {
                Section { ChangesCard(changes: changes) }
            }
            // UI-12: no section headers; the content says what it is. Phase lines
            // frame the screen, then one hero number, its chart, and steps.
            Section {
                if let lines = PhaseLine.lines(programme: programme, start: profile.programme.startDate,
                                               on: now, calendar: calendar) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lines.phase).font(.headline)
                        Text(lines.overall).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("progress.phase")
                }
                VStack(alignment: .leading, spacing: Space.xs) {
                    if let weight = BodyStats.shared.weight {
                        Text("\(WeightTrend.oneDecimal(weight.averageKg)) kg")
                            .font(.coachNumber(48))
                            .accessibilityIdentifier("progress.weight")
                        let change = WeightTrend.changeSinceStart(samples: BodyStats.shared.weightHistory,
                                                                  start: profile.programme.startDate,
                                                                  now: now, calendar: calendar)
                        // N7: the waist joins the line when it is on and measured.
                        let waist = WaistStore.shared.shownLog?.text
                        Text(WeightTrend.heroSubline(changeSinceStart: change) + (waist.map { " · \($0)" } ?? ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("progress.weightChange")
                    } else {
                        Text("No trend yet. It needs 3 weigh-ins in a week from the scale.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("progress.weight")
                    }
                    // QA-30: steps were read but shown nowhere; one quiet line under the hero.
                    if let steps = BodyStats.shared.steps {
                        Text(Self.stepsLine(steps))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("progress.steps")
                    }
                }
                .accessibilityElement(children: .contain)
                WeightHero(samples: BodyStats.shared.weightSamples, now: now, calendar: calendar)
            }

            // Hidden until there is data (rule 4).
            let lifts = StrengthProgress.lifts(from: history)
            if !lifts.isEmpty {
                Section {
                    ForEach(lifts, id: \.exercise) { lift in
                        HStack {
                            Text(content.exercises.exercise(lift.exercise)?.name ?? lift.exercise)
                            Spacer()
                            // Up is green; held or lighter stays neutral grey, never red (UI pass).
                            Text(StrengthProgress.change(lift))
                                .foregroundStyle(StrengthProgress.loadWentUp(lift) ? AnyShapeStyle(.go) : AnyShapeStyle(.secondary))
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("progress.lift.\(lift.exercise)")
                    }
                }
            }

            Section {
                if PhotoSchedule.isDue(on: now, start: profile.programme.startDate, taken: sets.map(\.date), calendar: calendar) {
                    // A card only on photo day.
                    Button { photoDay = true } label: {
                        Label("Photo day: front and side, 1 minute", systemImage: "camera")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    }
                    .accessibilityIdentifier("progress.photoDay")
                }
                // Otherwise one disclosure row; the photos themselves are one tap away.
                let next = profile.programme.startDate.flatMap {
                    PhotoSchedule.nextPhotoDay(after: now, start: $0, calendar: calendar)
                }
                if next != nil || !sets.isEmpty {
                    // N7: straight onto the compare view; every set is one more tap.
                    NavigationLink {
                        PhotoCompareView(sets: sets, start: profile.programme.startDate, calendar: calendar)
                    } label: {
                        Text(next.map { "Photos · next \($0.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))" } ?? "Photos")
                    }
                    .accessibilityIdentifier("progress.nextPhotos")
                }
            }

            // Optional actions, out of the way at the bottom.
            Section {
                let blocks = CoachBlockStore().all
                let weights = BodyStats.shared.weightHistory
                if let review = CoachReview.make(programme: programme, profile: profile, history: history,
                                                 weights: weights, blocks: blocks, checkIns: CheckInStore.shared.all,
                                                 now: now, calendar: calendar) {
                    ForEach(Array(review.flags.enumerated()), id: \.offset) { index, flag in
                        Label(flag.line, systemImage: "flag")
                            .foregroundStyle(.caution)
                            .accessibilityIdentifier("progress.flag.\(index)")
                    }
                    if let note = review.block?.note, !note.isEmpty {
                        Text(note).foregroundStyle(.secondary).accessibilityIdentifier("progress.coachNote")
                    }
                }
                // M4-02: the summary is text only; no photos, no raw Health samples.
                // C1: how the last 7 days' planned meals went, as counts and averages only.
                let meals = MealAdherence.lastSevenDays(now: now, plan: { monday in
                    MealPlan.coached(monday: monday, now: now, content: content.nutrition,
                                     lunchOrders: content.lunchOrders.orders,
                                     answers: WeekAnswersStore.shared.answers(weekStarting: monday, calendar: calendar),
                                     programme: programme, profile: profile, history: history, weights: weights,
                                     blocks: blocks, dislikes: { profile.dislikes(on: $0, calendar: calendar) },
                                     calendar: calendar)
                        .withSocialMeals(SocialMealStore.shared.dates(calendar: calendar), calendar: calendar)
                }, isTicked: { day, meal in MealTicks.shared.isTicked(meal, on: day.date, calendar: calendar) },
                calendar: calendar)
                let summaryText = { (waist: WaistLog?) in
                    CoachSummary.text(programme: programme, profile: profile, history: history,
                                      weights: weights, meals: meals, waist: waist, blocks: blocks,
                                      socialMeals: SocialMealStore.shared.dates(calendar: calendar),
                                      checkIns: CheckInStore.shared.all, now: now, calendar: calendar)
                }
                if let summary = summaryText(WaistStore.shared.shownLog) {
                    // Advisor (N7): a summary carrying the waist is shown in full before it
                    // can be shared. Otherwise straight to the share sheet (K1, 2 taps).
                    let hasWaist = WaistStore.shared.shownLog != nil && summary != summaryText(nil)
                    Group {
                        if hasWaist {
                            Button { previewSummary = summary } label: { askLabel }
                        } else {
                            ShareLink(item: summary) { askLabel }
                        }
                    }
                    .accessibilityIdentifier("progress.askCoach")
                    .id(Self.askRow)
                }
                // Coach Engineer's import (#54): copy Claude's reply, then tap.
                CoachImportButton(profile: profile, onImported: { version += 1 },
                                  onResult: { importResults += 1 })
                    .id(Self.importRow)
            }
        }
        // QA-32: the last rows can scroll clear of the floating tab bar, and a new
        // import result is brought into view rather than left behind the bar.
        .contentMargins(.bottom, 96, for: .scrollContent)
        .task(id: showAskCoach) {
            guard showAskCoach else { return }
            try? await Task.sleep(for: .milliseconds(300)) // let the tab switch and the list lay out
            withAnimation(.coach) { proxy.scrollTo(Self.askRow, anchor: .center) }
            showAskCoach = false
        }
        .onChange(of: importResults) {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150)) // let the row grow first
                withAnimation(.coach) { proxy.scrollTo(Self.importRow, anchor: .center) }
            }
        }
        }
        .navigationTitle("Progress")
        .sheet(item: Binding(get: { previewSummary.map(SummaryPreview.Item.init) },
                             set: { previewSummary = $0?.value })) { text in
            SummaryPreview(summary: text.value)
        }
        // N7 (F1): a photo-day notification opens the camera straight away.
        .task(id: NotificationTaps.shared.pending) {
            guard NotificationTaps.shared.pending == .photoDay else { return }
            NotificationTaps.shared.pending = nil
            photoDay = true
        }
        .fullScreenCover(isPresented: $photoDay, onDismiss: { version += 1 }) {
            PhotoDayView(date: now, calendar: calendar)
        }
    }
}

/// Photos every 2 weeks, newest first (behind Compare, N7).
struct PhotoSetsView: View {
    let sets: [ProgressStore.PhotoSet]
    private var store: ProgressStore { .shared }
    private static let importRow = "coach.importRow"

    var body: some View {
        List {
            Section {
                if sets.isEmpty {
                    Text("Your first photos are on photo day.").foregroundStyle(.secondary)
                }
                ForEach(sets) { set in
                    HStack(spacing: 8) {
                        ForEach(ProgressStore.Pose.allCases) { pose in
                            if let image = store.image(day: set.day, pose: pose) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 96)
                                    .clipShape(.rect(cornerRadius: 8))
                                    .accessibilityLabel("\(pose.title) photo")
                            }
                        }
                        Text(set.date.formatted(.dateTime.day().month(.abbreviated)))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .accessibilityIdentifier("progress.photoSet.\(set.day)")
                }
            } footer: {
                Text("Kept on this phone and in your own iCloud backup. Never shared.")
            }
        }
        .navigationTitle("Photos every 2 weeks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The Progress hero: the 7-day average as a line, the daily weigh-ins as faint dots.
private struct WeightHero: View {
    let samples: [WeightSample]
    let now: Date
    let calendar: Calendar

    var body: some View {
        let from = calendar.date(byAdding: .day, value: -27, to: calendar.startOfDay(for: now)) ?? now
        let recent = samples.filter { $0.date >= from }
        let line = WeightChart.averages(samples: samples, endingOn: now, days: 28, calendar: calendar)
        if !recent.isEmpty {
            let kgs = recent.map(\.kg) + line.map(\.averageKg)
            let low = (kgs.min() ?? 0) - 0.5, high = (kgs.max() ?? 0) + 0.5
            Chart {
                ForEach(recent, id: \.date) { sample in
                    PointMark(x: .value("Day", sample.date), y: .value("Weigh-in", sample.kg))
                        .symbolSize(18)
                        .foregroundStyle(.secondary.opacity(0.45))
                }
                ForEach(line, id: \.day) { point in
                    LineMark(x: .value("Day", point.day), y: .value("7-day average", point.averageKg))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(.tint)
                }
            }
            .chartYScale(domain: low...high)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), collisionResolution: .greedy)
                }
            }
            // QA-22: room for the last date label at the right edge.
            .padding(.trailing, 12)
            .frame(height: 160)
            .accessibilityLabel("Weight, 7-day average over the last 4 weeks")
            .accessibilityIdentifier("progress.weightChart")
        }
    }
}

extension ProgressScreen {
    fileprivate var askLabel: some View {
        Label("Ask the coach now", systemImage: "bubble.left.and.text.bubble.right")
    }
}

/// The full Claude summary, read before it is shared (`coach.preview`).
struct SummaryPreview: View {
    struct Item: Identifiable {
        let value: String
        var id: String { value }
    }

    let summary: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                SwiftUI.Text(summary)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .accessibilityIdentifier("coach.previewText")
            }
            .navigationTitle("What Claude will see")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("coach.preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("coach.previewCancel")
                }
            }
            .safeAreaInset(edge: .bottom) {
                ActionBar {
                    ShareLink(item: summary) { SwiftUI.Text("Share").frame(maxWidth: .infinity) }
                        .buttonStyle(PrimaryActionStyle())
                        .accessibilityIdentifier("coach.previewShare")
                }
            }
        }
    }
}
