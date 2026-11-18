import CoachCore
import SwiftUI
import UIKit

/// "Import Claude's reply" (board M4-02, plan §4.6). One tap reads the
/// clipboard once, checks the block and stores it, then shows one plain line:
/// imported, or why not with "Your plan hasn't changed." No dialog, no confirm.
/// Placed under "Ask the coach now" on Progress (M4-03); the line shows above the button.
struct CoachImportButton: View {
    let profile: Profile
    var onImported: () -> Void = {}

    @State private var result: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // QA-32: the result goes above the button, where the tap was, so it
            // lands on screen. Below it, it sat behind the tab bar at the list's end.
            if let result {
                Text(result)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach.import.result")
            }
            Button("Import Claude's reply") { importReply() }
                .buttonStyle(SecondaryActionStyle())
                .accessibilityIdentifier("coach.import")
        }
        .animation(.coach, value: result)
    }

    private func importReply() {
        let text = LaunchOptions.current.clipboard ?? UIPasteboard.general.string ?? ""
        guard let content = try? BundledContent.load(),
              let programme = content.programmes[profile.programme.programmeID] else {
            result = "The training plan couldn't be read, so nothing was imported. " + CoachImportError.unchanged
            return
        }
        let store = CoachBlockStore()
        let outcome = CoachImport.importing(text, into: store.all, programme: programme, profile: profile,
                                            now: AppClock.now())
        if outcome.accepted != nil {
            do {
                try store.replace(with: outcome.blocks)
            } catch {
                result = "The reply couldn't be saved. " + CoachImportError.unchanged
                return
            }
            onImported()
        }
        result = outcome.message
    }
}
