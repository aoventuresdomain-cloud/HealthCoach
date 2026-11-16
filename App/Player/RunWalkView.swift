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
                        .background(Color(.tertiarySystemFill), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End run")
                .accessibilityIdentifier("run.end")
                Text("\(model.plan.name) · Week \(model.plan.week)").font(.headline)
                Spacer()
                Text(model.voiceOn ? "Voice on" : "Voice off").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                content(at: context.date)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(Color(.systemGroupedBackground))
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
                Text("Run-walk done").font(.largeTitle.bold()).padding(.top, 48)
                    .accessibilityIdentifier("run.doneTitle")
                Text("\(PlayerFormat.clock(model.plan.totalSeconds)) · \(model.plan.repeats) jogs")
                    .font(.title3).foregroundStyle(.secondary)
            } else if let segment = model.segment {
                Text(RunWalkFormat.progress(model.plan, segment).uppercased())
                    .font(.headline).foregroundStyle(.secondary)
                    .padding(.top, 32)
                Text(RunWalkFormat.label(segment.kind))
                    .font(.system(size: segment.kind == .jog || segment.kind == .walk ? 88 : 44, weight: .heavy))
                    .foregroundStyle(segment.isJog ? .green : .blue)
                    .accessibilityIdentifier("run.label")
                let left = model.pausedRemaining ?? model.endsAt.map { max(0, Int($0.timeIntervalSince(date).rounded(.up))) } ?? 0
                Text(PlayerFormat.clock(left))
                    .font(.system(size: 112, weight: .bold).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityIdentifier("run.clock")
                Text(RunWalkFormat.nextUp(model.plan, after: model.index))
                    .font(.title2.bold()).foregroundStyle(.secondary)
                Text(RunWalkPlan.effortLine.trimmingCharacters(in: .punctuationCharacters))
                    .foregroundStyle(.secondary)
                SegmentBar(plan: model.plan, current: model.index)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                Text("\(PlayerFormat.clock(times.gone)) gone · \(PlayerFormat.clock(times.toGo)) to go")
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
            HStack {
                Text("Warm-up walk")
                Spacer()
                Text("\(plan.repeats) × jog, walk")
                Spacer()
                Text("Cool-down")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }

    private func colour(_ i: Int, _ segment: RunWalkPlan.Segment) -> Color {
        if i > current { return Color(.tertiarySystemFill) }
        return segment.isJog ? .green.opacity(i == current ? 0.5 : 1) : .blue.opacity(i == current ? 0.5 : 1)
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
            if let minutes { Text("About \(minutes) min, at your pace").foregroundStyle(.secondary) }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(PlayerFormat.clock(Int(context.date.timeIntervalSince(log.startedAt))))
                    .font(.system(size: 96, weight: .bold).monospacedDigit())
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
