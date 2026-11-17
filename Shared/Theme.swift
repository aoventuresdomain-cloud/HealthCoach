import SwiftUI

// Design tokens (docs/design/direction.md, UI pass 1). In Shared/ rather than
// App/Design/ so the Live Activity uses the same numerals and colours.
// Use these names instead of literals in new and touched code.

enum Space {            // 4-pt grid
    static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12
    static let l: CGFloat = 16   // screen gutter, gap between cards
    static let xl: CGFloat = 20  // card padding
    static let xxl: CGFloat = 24
}

enum Radius {
    static let card: CGFloat = 20, primary: CGFloat = 22, secondary: CGFloat = 16, pill: CGFloat = 14
}

extension Color {
    static let go = Color.green          // primary, jog, progress, loads going up
    static let rest = Color.blue         // rest, walk
    static let caution = Color.orange    // warnings, Guess, Fix
    static let onGo = Color.black        // text on green (white fails 4.5:1)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let canvas = Color(.systemGroupedBackground)
}

extension ShapeStyle where Self == Color {
    static var go: Color { .go }
    static var rest: Color { .rest }
    static var caution: Color { .caution }
    static var onGo: Color { .onGo }
}

extension Font {
    /// Big live numbers: rounded, bold, fixed-width digits so they don't jitter.
    static func coachNumber(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
    /// Large symbols drawn as text (icons, not numbers).
    static func coachSymbol(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    /// Small caps-style labels above numbers ("REST", "DIAL TO").
    static let coachLabel = Font.footnote.weight(.semibold)
}

extension Animation {
    static let coach = Animation.snappy(duration: 0.3)
}

/// UI-3: numbers roll instead of jumping; with Reduce Motion they just change.
struct RollingNumber<Value: Equatable>: ViewModifier {
    let value: Value
    var countsDown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .identity : .numericText(countsDown: countsDown))
            .animation(reduceMotion ? nil : .coach, value: value)
    }
}

extension View {
    func rollingNumber<Value: Equatable>(_ value: Value, countsDown: Bool = false) -> some View {
        modifier(RollingNumber(value: value, countsDown: countsDown))
    }
}
