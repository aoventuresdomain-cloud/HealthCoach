import CoachCore
import SwiftData
import SwiftUI

/// One line under `-uitest` that proves the launch flags took effect: the
/// injected clock, the stored profile's state and the bundled content.
/// Never shown otherwise.
struct UITestStatus: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        Text(summary)
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("debug.launch")
    }

    private var summary: String {
        let now = AppClock.now().formatted(.iso8601)
        let profile: String
        do {
            if let stored = try ProfileStore(context: context).load() {
                profile = stored.confirmed ? "confirmed" : "unconfirmed"
            } else {
                profile = "none"
            }
        } catch {
            profile = "error"
        }
        let content: String
        if let library = try? BundledContent.load() {
            content = "ok(\(library.exercises.exercises.count) exercises, \(library.programmes.count) programmes)"
        } else {
            content = "error"
        }
        let alarms: String
        // The next wake alarm, so a UI test can match it to Today's wake row (§A A9).
        var next = "none"
        switch WakeAlarms.shared.coverage {
        case let .allSet(count, date)?: alarms = "\(count)"; next = date.formatted(.iso8601)
        case let .reSet(_, total, date)?: alarms = "\(total)"; next = date.formatted(.iso8601)
        case .noAlarms?: alarms = "none"
        case nil: alarms = "pending"
        }
        let weather: String
        switch MorningWeather.shared.decision {
        case let .swap(swap)?: weather = "swap(\(swap.to))"
        case let .keep(reason)?: weather = reason.rawValue
        case nil: weather = "pending"
        }
        // QA-17: past the programme's last week the plan holds at it (E13).
        var held = "0"
        if let stored = try? ProfileStore(context: context).load(), let start = stored.programme.startDate,
           let programme = (try? BundledContent.load())?.programmes[stored.programme.programmeID],
           programme.plannedDay(on: AppClock.now(), start: start, calendar: .coach).heldAtLastWeek {
            held = "1"
        }
        let stats = BodyStats.shared
        let weight = !stats.hasRead ? "pending" : stats.weight.map { WeightTrend.oneDecimal($0.averageKg) } ?? "none"
        return "now=\(now) profile=\(profile) content=\(content) alarms=\(alarms) weather=\(weather) weight=\(weight) held=\(held) next=\(next)"
    }
}
