import CoachCore
import SwiftUI

/// Run-walk screen (board M1-07, design screen 6): only the current interval,
/// time left, what's next, a segment bar and one small stats line. One button.
struct RunWalkView: View {
    @State var model: RunWalkModel
    var onClose: (SessionLog) -> Void

    @State private var confirmingEnd = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { if model.finished { onClose(model.close(now: AppClock.now())) } else { confirmingEnd = true } } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle) // UI-5: glass chrome
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End run")
                .accessibilityIdentifier("run.end")
                Spacer()
                // UI-12: no title (you started it from Today); only the exception is said.
                if !model.voiceOn {
                    Text("Voice off").foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                content(at: context.date)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        // UI-10: the screen is washed in the interval's colour, readable from across the room.
        .background {
            ZStack {
                Color(.systemGroupedBackground)
                (model.segment?.isJog == true ? Color.go : Color.rest)
                    .opacity(model.finished ? 0 : 0.12)
            }
            .ignoresSafeArea()
            .animation(.coach, value: model.index)
        }
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                if model.finished {
                    Button("Done") { onClose(model.close(now: AppClock.now())) }
                        .buttonStyle(PrimaryActionStyle())
                        .accessibilityIdentifier("run.finish")
                } else {
                    Button(model.isPaused ? "Resume" : "Pause") { model.togglePause() }
                        .buttonStyle(PlainGreyLargeStyle())
                        .accessibilityIdentifier("run.pause")
                }
            }
        }
        // UI-2: heavy on each interval change, success when the run-walk ends.
        .sensoryFeedback(.impact(weight: .heavy), trigger: model.index)
        .sensoryFeedback(trigger: model.finished) { _, new in new ? .success : nil }
        .onAppear { model.begin() }
        .confirmationDialog("End this run?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End run", role: .destructive) { onClose(model.close(now: AppClock.now())) }
                .accessibilityIdentifier("run.endConfirm")
            Button("Keep going", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func content(at date: Date) -> some View {
        let times = model.elapsedAndRemaining(at: date)
        VStack(spacing: 12) {
            if model.finished {
                Text(model.plan.repeats == 0 ? "Walk done" : "Run-walk done").font(.largeTitle.bold()).padding(.top, 48)
                    .accessibilityIdentifier("run.doneTitle")
                Text(model.plan.repeats == 0 ? PlayerFormat.clock(model.plan.totalSeconds)
                     : "\(PlayerFormat.clock(model.plan.totalSeconds)) · \(model.plan.repeats) jogs")
                    .font(.title3).foregroundStyle(.secondary)
            } else if let segment = model.segment {
                Text(RunWalkFormat.label(segment.kind))
                    .font(.coachNumber(segment.kind == .jog || segment.kind == .walk ? 88 : 44, weight: .heavy))
                    .foregroundStyle(segment.isJog ? Color.go : Color.rest)
                    .padding(.top, 32)
                    .accessibilityLabel("\(RunWalkFormat.label(segment.kind)), \(RunWalkFormat.progress(model.plan, segment))")
                    .accessibilityIdentifier("run.label")
                let left = model.pausedRemaining ?? model.endsAt.map { max(0, Int($0.timeIntervalSince(date).rounded(.up))) } ?? 0
                Text(PlayerFormat.clock(left))
                    .font(.coachNumber(112))
                    .rollingNumber(left, countsDown: true)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityIdentifier("run.clock")
                Text(RunWalkFormat.nextUp(model.plan, after: model.index))
                    .font(.title2.bold()).foregroundStyle(.secondary)
                // UI-12: easy pace on the warm-up and the first jog only; the voice says it too.
                if segment.kind == .warmUp || (segment.kind == .jog && segment.interval == 1) {
                    Text(RunWalkPlan.effortLine.trimmingCharacters(in: .punctuationCharacters))
                        .foregroundStyle(.secondary)
                }
                SegmentBar(plan: model.plan, current: model.index)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                Text("\(PlayerFormat.clock(times.toGo)) to go")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("run.stats")
                if model.isPaused {
                    Text("Paused").font(.headline).foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SegmentBar: View {
    let plan: RunWalkPlan
    let current: Int

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let total = CGFloat(max(plan.totalSeconds, 1))
                let gaps = CGFloat(max(plan.segments.count - 1, 0)) * 3
                HStack(spacing: 3) {
                    ForEach(Array(plan.segments.enumerated()), id: \.offset) { i, segment in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colour(i, segment))
                            .overlay {
                                if i == current { RoundedRectangle(cornerRadius: 4).stroke(Color.green, lineWidth: 2) }
                            }
                            .frame(width: max(4, (geo.size.width - gaps) * CGFloat(segment.seconds) / total))
                    }
                }
            }
            .frame(height: 22)
        }
        .accessibilityHidden(true)
    }

    private func colour(_ i: Int, _ segment: RunWalkPlan.Segment) -> Color {
        if i > current { return Color(.tertiarySystemFill) }
        return segment.isJog ? Color.go.opacity(i == current ? 0.5 : 1) : Color.rest.opacity(i == current ? 0.5 : 1)
    }
}

/// The optional Sunday walk (and the swap-only circuit until it gets its own
/// player): a running clock and Done.
struct WalkView: View {
    let name: String
    let minutes: Int?
    @State var log: SessionLog
    var onClose: (SessionLog) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(name).font(.largeTitle.bold()).padding(.top, 48)
                .accessibilityIdentifier("walk.title")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let gone = Int(context.date.timeIntervalSince(log.startedAt))
                VStack(spacing: 8) {
                    Text(PlayerFormat.clock(gone))
                        .font(.coachNumber(96))
                    // UI-12: the same rule as the run-walk, "to go" only.
                    if let minutes {
                        Text("\(PlayerFormat.clock(max(0, minutes * 60 - gone))) to go")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("walk.toGo")
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button("Done") {
                    log.finishedAt = AppClock.now()
                    onClose(log)
                }
                .buttonStyle(PrimaryActionStyle())
                .accessibilityIdentifier("walk.finish")
            }
        }
    }
}
