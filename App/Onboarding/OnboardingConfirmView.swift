import CoachCore
import SwiftUI

/// Onboarding confirm (board M1-04, design screen 7): one scroll of rows
/// pre-filled from the profile defaults (decision E6), edited inline, then
/// "Looks right". Only the three unconfirmed defaults are marked Guess.
struct OnboardingConfirmView: View {
    @Binding var profile: Profile
    let programme: Programme
    var onConfirm: () -> Void

    @State private var editing: Row?
    @State private var showingMore = false

    /// UI-12: the guesses and the safety default, which need a glance (Advisor).
    static let toCheck: [Row] = [.paperStart, .sleep, .work, .longest, .hurts]
    /// Confirmed already from what the owner said; one tap away.
    static let rest: [Row] = [.you, .goal, .office, .fixed, .kit, .cues, .checkIn]

    typealias Row = ProfileRow

    var body: some View {
        List {
            Section {
                Text("Check this, then you're set")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("onboarding.title")
                if LaunchOptions.current.isUITest {
                    UITestStatus()
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            Section {
                ForEach(Self.toCheck) { ProfileRowView(profile: $profile, programme: programme, row: $0, editing: $editing) }
            } header: {
                Text("Check these \(Self.toCheck.count)")
            }
            Section {
                Button {
                    withAnimation(.snappy) { showingMore.toggle() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Everything else (\(Self.rest.count))").foregroundStyle(.primary)
                            Text("From what you told us").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(showingMore ? 90 : 0))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(showingMore ? .isSelected : [])
                .accessibilityIdentifier("onboarding.more")
                if showingMore {
                    ForEach(Self.rest) { ProfileRowView(profile: $profile, programme: programme, row: $0, editing: $editing) }
                }
            }
        }
        .listStyle(.insetGrouped)
        // QA-36: rows scrolled up stop under a bar, not under the clock.
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(.bar, ignoresSafeAreaEdges: .top)
        }
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button("Looks right", action: onConfirm)
                    .buttonStyle(PrimaryActionStyle())
                    .accessibilityIdentifier("onboarding.confirm")
            }
        }
    }
}

/// Edits a `TimeOfDay` with the system wheel, in place.
struct TimeOfDayPicker: View {
    let title: String
    @Binding var time: TimeOfDay

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .gmt
        return c
    }

    var body: some View {
        DatePicker(title, selection: Binding(
            get: { Self.calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: time.hour, minute: time.minute)) ?? .now },
            set: {
                let parts = Self.calendar.dateComponents([.hour, .minute], from: $0)
                time = TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
            }
        ), displayedComponents: .hourAndMinute)
        .environment(\.timeZone, .gmt)
    }
}

enum OnboardingFormat {
    /// Offered under "Anything that hurts"; stored lower-case in the profile.
    static let areas = ["shoulders", "elbows", "wrists", "lower back", "knees"]

    static func area(_ area: String) -> String { area.prefix(1).uppercased() + area.dropFirst() }

    static func target(_ target: Profile.Goal.Target) -> String {
        switch target {
        case .leanAndDefined: "Lean and defined"
        case .leanAndStrong: "Lean and strong"
        case .buildMuscle: "Build muscle"
        case .generalFitness: "General fitness"
        }
    }

    static func counting(_ counting: Profile.Training.Counting) -> String {
        switch counting {
        case .tap: "tap to count"
        case .voice: "count by voice"
        case .both: "tap or voice"
        }
    }

    static func kg(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(0...1)))
    }

    static func hours(_ hours: Double) -> String {
        hours.formatted(.number.precision(.fractionLength(0...2)))
    }
}
