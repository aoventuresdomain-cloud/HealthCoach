import CoachCore
import SwiftUI

/// The workout player (board M1-06, design screens 3–5): one primary button
/// in the thumb zone, numbers readable at 1.5 m, callouts always visible,
/// End (✕) top-left and out of reach.
struct WorkoutPlayerView: View {
    @State var model: WorkoutPlayerModel
    /// Called once with the log: finished, or ended early (finishedAt nil).
    var onClose: (SessionLog) -> Void

    @State private var confirmingEnd = false
    @State private var editing = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch model.phase {
                case let .warmUp(i): WarmUpScreen(model: model, index: i)
                case let .set(i): SetScreen(model: model, step: model.script.sets[i])
                case let .rest(next): RestScreen(model: model, upcoming: model.script.sets[next])
                case .done: DoneScreen(model: model)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { actions }
        .onAppear { model.begin() }
        .confirmationDialog("End this session?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End and keep what's logged", role: .destructive) {
                model.end()
                onClose(model.log)
            }
            .accessibilityIdentifier("player.endConfirm")
            Button("Keep going", role: .cancel) {}
        }
        .sheet(isPresented: $editing) {
            EditSetsView(model: model)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                confirmingEnd = true
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemFill), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End session")
            .accessibilityIdentifier("player.end")
            ProgressSegments(total: model.script.exerciseCount, current: model.exerciseNumber)
            Text(model.exerciseNumber == 0 ? "Warm-up" : "\(model.exerciseNumber) / \(model.script.exerciseCount)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("player.progress")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var actions: some View {
        switch model.phase {
        case .warmUp:
            ActionBar {
                Button("Next") { model.next() }
                    .buttonStyle(PrimaryActionStyle())
                    .accessibilityIdentifier("player.next")
            }
        case let .set(i):
            ActionBar {
                Button(doneLabel(model.script.sets[i])) { model.done() }
                    .buttonStyle(PrimaryActionStyle())
                    .accessibilityIdentifier("player.done")
            }
        case .rest:
            ActionBar {
                Button("+30 s") { model.rest.extend(by: 30) }
                    .buttonStyle(SecondaryActionStyle())
                    .accessibilityIdentifier("player.extendRest")
            } primary: {
                Button("Next") { model.next() }
                    .buttonStyle(PrimaryActionStyle())
                    .accessibilityIdentifier("player.next")
            }
        case .done:
            ActionBar {
                Button("Something was different") { editing = true }
                    .buttonStyle(SecondaryActionStyle())
                    .accessibilityIdentifier("player.edit")
            } primary: {
                Button("Done") { onClose(model.finish(now: AppClock.now())) }
                    .buttonStyle(PrimaryActionStyle())
                    .accessibilityIdentifier("player.finish")
            }
        }
    }

    private func doneLabel(_ step: WorkoutScript.SetStep) -> String {
        if case .perSide = step.kind, model.side == .left { return "Done · left" }
        if case .perSide = step.kind { return "Done · right" }
        return "Done"
    }
}

// MARK: - Screens

private struct WarmUpScreen: View {
    let model: WorkoutPlayerModel
    let index: Int

    var body: some View {
        let move = model.script.warmUp[index]
        VStack(alignment: .leading, spacing: 16) {
            ExerciseMediaView(exercise: model.exercise(move.exercise))
                .frame(height: 220)
            Text("WARM-UP · \(index + 1) OF \(model.script.warmUp.count)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(model.name(move.exercise))
                .font(.largeTitle.bold())
                .accessibilityIdentifier("player.exerciseName")
            Text("\(move.reps)\(move.perSide ? " each side" : "")\(move.kg.map { " · \(PlayerFormat.kg($0)) kg" } ?? "")")
                .font(.title.bold().monospacedDigit())
            if let callouts = model.exercise(move.exercise)?.callouts {
                CalloutsCard(callouts: callouts)
            }
            Text("Moves on by itself. Next skips ahead.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }
}

private struct SetScreen: View {
    let model: WorkoutPlayerModel
    let step: WorkoutScript.SetStep

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ExerciseMediaView(exercise: model.exercise(step.exercise))
                .frame(minHeight: 140, idealHeight: 220, maxHeight: 220)
            Text(model.name(step.exercise))
                .font(.title.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("player.exerciseName")
            numbers
            if let cue = step.cue {
                Text(cue).font(.headline).foregroundStyle(.green)
            } else if let note = step.note {
                Text(note).font(.headline).foregroundStyle(.green)
            }
            if step.slowTempo {
                Text("Lower over 3 seconds this time.")
                    .font(.headline)
                    .accessibilityIdentifier("player.slowTempo")
            }
            if step.atDumbbellLimit {
                Text("Next step is past your heaviest dumbbell.")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("player.dumbbellLimit")
            }
            if let callouts = model.exercise(step.exercise)?.callouts {
                CalloutsCard(callouts: callouts)
                    .layoutPriority(-1)
            }
            counter
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var numbers: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            BigNumber(value: "\(step.setIndex + 1)", suffix: "/\(step.setCount)", label: "SET")
            switch step.kind {
            case let .reps(target):
                BigNumber(value: "\(target)", label: "REPS")
                BigNumber(value: step.kg.map(PlayerFormat.kg) ?? "BW", label: step.kg == nil ? "BODYWEIGHT" : "KG EACH")
            case let .perSide(target):
                BigNumber(value: "\(target)", label: model.side == .right ? "REPS · RIGHT" : "REPS · LEFT")
                BigNumber(value: step.kg.map(PlayerFormat.kg) ?? "BW", label: step.kg == nil ? "BODYWEIGHT" : "KG")
            case let .hold(seconds):
                BigNumber(value: model.gettingReady ? "Ready" : PlayerFormat.clock(seconds - model.held),
                          label: model.gettingReady ? "GET IN POSITION" : "HOLD")
            case let .negatives(reps, lower):
                BigNumber(value: "\(reps)", label: "LOWERS")
                BigNumber(value: "\(lower) s", label: "EACH")
            }
        }
    }

    @ViewBuilder
    private var counter: some View {
        switch step.kind {
        case .reps(let target), .perSide(let target), .negatives(let target, _):
            Button { model.tapCount() } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(model.count)").font(.system(size: 56, weight: .bold).monospacedDigit())
                    Text("/ \(target)").font(.title.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer()
                    Text("Tap anywhere here\nto count (optional)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: 92)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundStyle(.secondary.opacity(0.5)))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rep counter, \(model.count) of \(target)")
            .accessibilityHint("Tap to count a rep. Optional.")
            .accessibilityIdentifier("player.counter")
        case .hold:
            EmptyView()
        }
    }
}

private struct RestScreen: View {
    let model: WorkoutPlayerModel
    let upcoming: WorkoutScript.SetStep

    var body: some View {
        VStack(spacing: 24) {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let remaining = max(0, Int((model.rest.endsAt?.timeIntervalSince(context.date) ?? 0).rounded(.up)))
                let total = max(model.rest.totalSeconds, 1)
                ZStack {
                    Circle().stroke(Color(.tertiarySystemFill), lineWidth: 18)
                    Circle()
                        .trim(from: 0, to: CGFloat(remaining) / CGFloat(total))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text("REST").font(.headline).foregroundStyle(.secondary)
                        Text(PlayerFormat.clock(remaining))
                            .font(.system(size: 76, weight: .bold).monospacedDigit())
                            .accessibilityIdentifier("player.restClock")
                        Text("of \(PlayerFormat.clock(total))").foregroundStyle(.secondary)
                    }
                }
                .frame(width: 260, height: 260)
                .padding(.top, 16)
            }
            HStack(spacing: 14) {
                // QA-13: the mock-up's thumbnail of what's next.
                ExerciseMediaView(exercise: model.exercise(upcoming.exercise), compact: true)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT · \(upcoming.exerciseNumber) OF \(model.script.exerciseCount)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(model.name(upcoming.exercise)).font(.title3.bold())
                    Text(RestScreen.summary(upcoming)).foregroundStyle(.secondary)
                }
                Spacer()
                if let kg = upcoming.kg {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("DIAL TO").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(PlayerFormat.kg(kg)).font(.system(size: 52, weight: .bold).monospacedDigit())
                            Text("kg").font(.title3.bold())
                        }
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("player.dialTo")
                    }
                }
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            .padding(.horizontal, 16)
            Text("Voice says \"3, 2, 1, go\" in your headphones. Also on the lock screen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    /// "2 sets × 10 each side" before an exercise's first set (as the mock-up);
    /// "Set 2 of 2 · 8 reps" between its sets, never "1 set × 8" (QA-13).
    static func summary(_ step: WorkoutScript.SetStep) -> String {
        if step.setIndex > 0 {
            let of = "Set \(step.setIndex + 1) of \(step.setCount)"
            switch step.kind {
            case let .reps(target): return "\(of) · \(target) reps"
            case let .perSide(target): return "\(of) · \(target) each side"
            case let .hold(seconds): return "\(of) · \(seconds) s hold"
            case let .negatives(reps, lower): return "\(of) · \(reps) lowers, \(lower) s"
            }
        }
        let sets = "\(step.setCount) \(step.setCount == 1 ? "set" : "sets")"
        switch step.kind {
        case let .reps(target): return "\(sets) × \(target)"
        case let .perSide(target): return "\(sets) × \(target) each side"
        case let .hold(seconds): return "\(sets) × \(seconds) s hold"
        case let .negatives(reps, lower): return "\(sets) × \(reps) lowers, \(lower) s"
        }
    }
}

private struct DoneScreen: View {
    let model: WorkoutPlayerModel

    var body: some View {
        let minutes = max(1, Int(AppClock.now().timeIntervalSince(model.log.startedAt) / 60))
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("\(model.script.name) done")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("player.doneTitle")
                HStack(spacing: 0) {
                    BigNumber(value: "\(minutes)", label: minutes == 1 ? "MINUTE" : "MINUTES")
                    BigNumber(value: "\(model.log.sets.count)", label: model.log.sets.count == 1 ? "SET" : "SETS")
                }
                VStack(spacing: 0) {
                    ForEach(DoneScreen.lifts(model), id: \.0) { exercise, line in
                        HStack {
                            Text(model.name(exercise))
                            Spacer()
                            Text(line).foregroundStyle(.secondary).monospacedDigit()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        Divider().padding(.leading, 16)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                let next = model.nextTime(model.log)
                if !next.isEmpty {
                    Text("NEXT TIME")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    VStack(spacing: 0) {
                        ForEach(next, id: \.exercise) { line in
                            HStack {
                                Text(model.name(line.exercise))
                                Spacer()
                                Text(line.text).foregroundStyle(.green).monospacedDigit()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("player.nextTime.\(line.exercise)")
                            Divider().padding(.leading, 16)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                }
                Text("Every set was logged as you went. Next time's loads follow from these.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
        }
    }

    /// One line per exercise: "2 × 8 @ 10 kg", or "2 × 20 s".
    static func lifts(_ model: WorkoutPlayerModel) -> [(String, String)] {
        var order: [String] = []
        var byExercise: [String: [SetLog]] = [:]
        for set in model.log.sets {
            if byExercise[set.exercise] == nil { order.append(set.exercise) }
            byExercise[set.exercise, default: []].append(set)
        }
        return order.map { exercise in
            let sets = byExercise[exercise] ?? []
            let amount = sets.compactMap { $0.reps ?? $0.seconds }.max() ?? 0
            let unit = sets.first?.seconds != nil ? " s" : ""
            let load = sets.first?.kg.map { " @ \(PlayerFormat.kg($0)) kg" } ?? ""
            return (exercise, "\(sets.count) × \(amount)\(unit)\(load)")
        }
    }
}

/// "Something was different": the logged sets with steppers, pre-filled.
private struct EditSetsView: View {
    let model: WorkoutPlayerModel
    @Environment(\.dismiss) private var dismiss
    @State private var sets: [SetLog] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(sets.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(model.name(sets[i].exercise)) · set \(sets[i].setIndex + 1)").font(.headline)
                        if sets[i].seconds != nil {
                            Stepper("\(sets[i].seconds ?? 0) s", value: secondsBinding(i), in: 0...600, step: 5)
                        } else {
                            Stepper("\(sets[i].reps ?? 0) reps", value: repsBinding(i), in: 0...100)
                        }
                        if sets[i].kg != nil {
                            Stepper("\(PlayerFormat.kg(sets[i].kg ?? 0)) kg", value: kgBinding(i), in: 0...60, step: 0.5)
                        }
                    }
                }
            }
            .navigationTitle("What was different")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.replaceSets(sets)
                        dismiss()
                    }
                    .accessibilityIdentifier("edit.save")
                }
            }
        }
        .onAppear { sets = model.log.sets }
    }

    // Any edit means the set wasn't exactly as prescribed.
    private func repsBinding(_ i: Int) -> Binding<Int> {
        Binding(get: { sets[i].reps ?? 0 }, set: { sets[i].reps = $0; sets[i].asPrescribed = false })
    }
    private func secondsBinding(_ i: Int) -> Binding<Int> {
        Binding(get: { sets[i].seconds ?? 0 }, set: { sets[i].seconds = $0; sets[i].asPrescribed = false })
    }
    private func kgBinding(_ i: Int) -> Binding<Double> {
        Binding(get: { sets[i].kg ?? 0 }, set: { sets[i].kg = $0; sets[i].asPrescribed = false })
    }
}

// MARK: - Pieces

struct BigNumber: View {
    let value: String
    var suffix: String? = nil
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value).font(.system(size: 48, weight: .bold).monospacedDigit())
                if let suffix {
                    Text(suffix).font(.title.bold().monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text(label).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct CalloutsCard: View {
    let callouts: Exercise.Callouts

    var body: some View {
        VStack(spacing: 0) {
            line("SETUP", callouts.setup, colour: .secondary)
            Divider()
            line("MOVE", callouts.movement, colour: .secondary)
            Divider()
            line("FIX", callouts.commonMistake, colour: .orange)
        }
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        .accessibilityIdentifier("player.callouts")
    }

    private func line(_ label: String, _ text: String, colour: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).font(.footnote.weight(.bold)).foregroundStyle(colour).frame(width: 52, alignment: .leading)
            Text(text).font(.callout).lineLimit(2).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

struct ProgressSegments: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i < current - 1 ? Color.green : i == current - 1 ? Color.green.opacity(0.6) : Color(.tertiarySystemFill))
                    .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}
