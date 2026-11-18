import CoachCore
import SwiftUI

/// N2 · What changed and why: one card, one line per change, at most four,
/// then "N more ›". A load that rises is green with ↑; a held or eased load
/// stays grey, never red (direction.md). No card when nothing changed.
struct ChangesCard: View {
    let changes: [CoachChange]
    @State private var showAll = false

    static let limit = 4

    var body: some View {
        if !changes.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("What changed").font(.headline)
                let shown = showAll ? changes : Array(changes.prefix(Self.limit))
                ForEach(Array(shown.enumerated()), id: \.offset) { index, change in
                    // The run-walk line keeps the id the check-in test asserts (N1).
                    line(change).accessibilityIdentifier(change.kind == .runWalk ? "checkin.runWalkLine" : "changes.line.\(index)")
                }
                if !showAll, changes.count > Self.limit {
                    Button("\(changes.count - Self.limit) more ›") { showAll = true }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("changes.more")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("changes.card")
        }
    }

    private func line(_ change: CoachChange) -> some View {
        let rises = Self.rises(change)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            if rises { Image(systemName: "arrow.up").accessibilityHidden(true) }
            Text(change.line).multilineTextAlignment(.leading)
        }
        .font(.subheadline)
        .foregroundStyle(rises ? AnyShapeStyle(.go) : AnyShapeStyle(.secondary))
    }

    /// True for a load line whose new weight is above the old one
    /// ("Goblet squat 12 kg → 14 kg per dumbbell: …").
    static func rises(_ change: CoachChange) -> Bool {
        guard change.kind == .load else { return false }
        let halves = change.line.components(separatedBy: " → ")
        guard halves.count == 2,
              let old = halves[0].split(separator: " ").dropLast().last.flatMap({ Double($0) }),
              let new = halves[1].split(separator: " ").first.flatMap({ Double($0) }) else { return false }
        return new > old
    }
}
