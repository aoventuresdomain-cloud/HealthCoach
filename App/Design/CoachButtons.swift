import CoachCore
import SwiftUI

// Layout rules from docs/design/m1/README.md: one primary action per screen,
// full width, 76 pt, green, pinned to the bottom; at most one secondary,
// 50 pt, grey, directly above it.

struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.bold())
            .frame(maxWidth: .infinity, minHeight: 76)
            .foregroundStyle(Color.onGo)
            .background(Color.go.opacity(configuration.isPressed ? 0.75 : 1), in: .rect(cornerRadius: 22))
            .contentShape(.rect)
    }
}

struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.primary)
            // UI-5: Liquid Glass on secondary chrome; the primary stays solid green.
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Radius.secondary))
            .contentShape(.rect)
    }
}

/// The bottom thumb zone: optional secondary above the primary.
struct ActionBar<Primary: View, Secondary: View>: View {
    @ViewBuilder var secondary: Secondary
    @ViewBuilder var primary: Primary

    var body: some View {
        VStack(spacing: 10) {
            secondary
            primary
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        // UI-5: no opaque fill, so the glass secondary sits on the canvas.
    }
}

extension ActionBar where Secondary == EmptyView {
    init(@ViewBuilder primary: () -> Primary) {
        self.init(secondary: { EmptyView() }, primary: primary)
    }
}

/// Orange "Guess" tag for defaults the owner never confirmed (design B9).
struct GuessTag: View {
    var body: some View {
        Text("GUESS")
            .font(.caption.bold())
            .foregroundStyle(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.18), in: .rect(cornerRadius: 6))
            .accessibilityLabel("Guess")
    }
}
