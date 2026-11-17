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

    @Environment(\.modelContext) private var context
    @State private var photoDay = false
    @State private var version = 0

    private let calendar = Calendar.coach
    private var store: ProgressStore { .shared }

    var body: some View {
        let _ = version
        let now = AppClock.now()
        let history = (try? SessionLogStore(context: context).all()) ?? []
        let sets = store.sets(calendar: calendar)
        List {
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
                WeightHero(samples: BodyStats.shared.weightSamples, now: now, calendar: calendar)
                if let weight = BodyStats.shared.weight {
                    Text(weight.summary).accessibilityIdentifier("progress.weight")
                } else {
                    Text("No trend yet. It needs 3 weigh-ins in a week from the scale.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("progress.weight")
                }
            } header: {
                Text("Weight")
            }

            Section("Strength") {
                let lifts = StrengthProgress.lifts(from: history)
                if lifts.isEmpty {
                    Text("Your lifts appear here after the first session.").foregroundStyle(.secondary)
                }
                ForEach(lifts, id: \.exercise) { lift in
                    HStack {
                        Text(content.exercises.exercise(lift.exercise)?.name ?? lift.exercise)
                        Spacer()
                        // Up is green; held or lighter stays neutral grey, never red (UI pass).
                        Text(StrengthProgress.change(lift))
                            .foregroundStyle(StrengthProgress.loadWentUp(lift) ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("progress.lift.\(lift.exercise)")
                }
            }

            Section {
                if PhotoSchedule.isDue(on: now, start: profile.programme.startDate, taken: sets.map(\.date), calendar: calendar) {
                    Button { photoDay = true } label: {
                        Label("Photo day: front and side, 1 minute", systemImage: "camera")
                    }
                    .accessibilityIdentifier("progress.photoDay")
                } else if let start = profile.programme.startDate,
                          let next = PhotoSchedule.nextPhotoDay(after: now, start: start, calendar: calendar) {
                    Text("Next photos \(next.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))).")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("progress.nextPhotos")
                }
                ForEach(sets.reversed()) { set in
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
            } header: {
                Text("Photos every 2 weeks")
            } footer: {
                Text("Kept on this phone and in your own iCloud backup. Never shared.")
            }

            Section {
                let blocks = CoachBlockStore().all
                let weights = BodyStats.shared.weightSamples
                if let review = CoachReview.make(programme: programme, profile: profile, history: history,
                                                 weights: weights, blocks: blocks, now: now, calendar: calendar) {
                    ForEach(Array(review.flags.enumerated()), id: \.offset) { index, flag in
                        Label(flag.line, systemImage: "flag")
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("progress.flag.\(index)")
                    }
                    if let note = review.block?.note, !note.isEmpty {
                        Text(note).foregroundStyle(.secondary).accessibilityIdentifier("progress.coachNote")
                    }
                }
                // M4-02: the summary is text only; no photos, no raw Health samples.
                if let summary = CoachSummary.text(programme: programme, profile: profile, history: history,
                                                   weights: weights, blocks: blocks, now: now, calendar: calendar) {
                    ShareLink(item: summary) {
                        Label("Ask the coach now", systemImage: "bubble.left.and.text.bubble.right")
                    }
                    .accessibilityIdentifier("progress.askCoach")
                }
                // Coach Engineer's import (#54): copy Claude's reply, then tap.
                CoachImportButton(profile: profile) { version += 1 }
            } footer: {
                Text("Builds a short summary, with no photos, for you to send to Claude. Then copy Claude's reply and import it.")
            }
        }
        .navigationTitle("Progress")
        .sheet(isPresented: $photoDay, onDismiss: { version += 1 }) {
            PhotoDayView(date: now, calendar: calendar)
        }
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
