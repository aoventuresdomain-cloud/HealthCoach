import CoachCore
import SwiftUI

/// N7 compare (`compare.view`): the latest front photo against week 0 or
/// 4 weeks ago, with a slider across the two, and the weight trend under
/// them in one line. Photos stay on the phone.
struct PhotoCompareView: View {
    /// Oldest first.
    let sets: [ProgressStore.PhotoSet]
    let start: Date?
    let calendar: Calendar

    @State private var against = PhotoPairing.Against.weekZero
    /// Share of the width showing the latest photo, from the left.
    @State private var split = 0.5

    private var store: ProgressStore { .shared }

    var body: some View {
        List {
            if let latest = sets.last,
               let index = PhotoPairing.baseline(sets.map(\.date), against: against, calendar: calendar) {
                let base = sets[index]
                Section {
                    Picker("Compare with", selection: $against) {
                        ForEach(PhotoPairing.available(sets.map(\.date), calendar: calendar), id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("compare.against")
                    overlay(latest: latest, base: base)
                    Slider(value: $split, in: 0...1)
                        .accessibilityLabel("Now and then")
                        .accessibilityIdentifier("compare.slider")
                    HStack {
                        Text("Now · \(short(latest.date))")
                        Spacer()
                        Text("\(against.rawValue) · \(short(base.date))")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if let line = weightLine {
                        Text(line).font(.subheadline.monospacedDigit()).accessibilityIdentifier("compare.weight")
                    }
                }
            } else {
                Section {
                    Text(sets.isEmpty ? "Your first photos are on photo day." : "Compare from your next photo day.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                NavigationLink("All photos") { PhotoSetsView(sets: Array(sets.reversed())) }
                    .accessibilityIdentifier("compare.all")
            } footer: {
                Text("Kept on this phone and in your own iCloud backup. Never shared.")
            }
        }
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compare.view")
    }

    private func overlay(latest: ProgressStore.PhotoSet, base: ProgressStore.PhotoSet) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                photo(base)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                photo(latest)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: geo.size.width * split)
                    }
                Rectangle()
                    .fill(.white)
                    .frame(width: 2, height: geo.size.height)
                    .offset(x: geo.size.width * split - 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 420)
        .clipShape(.rect(cornerRadius: 14))
        .accessibilityElement()
        .accessibilityLabel("Front photos, now and \(against.rawValue.lowercased())")
        .accessibilityIdentifier("compare.photos")
    }

    @ViewBuilder
    private func photo(_ set: ProgressStore.PhotoSet) -> some View {
        if let image = store.image(day: set.day, pose: .front) ?? store.image(day: set.day, pose: .side) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Color(.secondarySystemGroupedBackground)
        }
    }

    private func short(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// "82.4 kg · 7-day average · −1.1 kg since start · waist 88.5 cm (−1.5)", when there is a trend.
    private var weightLine: String? {
        let change = WeightTrend.changeSinceStart(samples: BodyStats.shared.weightHistory, start: start,
                                                  now: AppClock.now(), calendar: calendar)
        return ProgressLine.text(trend: BodyStats.shared.weight, changeSinceStart: change,
                                 waist: WaistStore.shared.shownLog)
    }
}
