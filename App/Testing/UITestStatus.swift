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
        return "now=\(now) profile=\(profile) content=\(content)"
    }
}
