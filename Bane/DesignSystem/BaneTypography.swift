import SwiftUI

/// Type scale for the Bane design system: a bold/tight grotesk for display and
/// headings, a monospaced face for anything tabular (reps, weight, timers).
///
/// The source system pairs Archivo (display) with IBM Plex Mono (data). Those
/// aren't bundled here, so this substitutes system fonts in the same two
/// registers — `.default` bold/heavy for display, `.monospaced` for data —
/// which carries the "cold grotesk + mono" feel without adding font assets.
/// Swap in real Archivo/IBM Plex Mono files later by pointing these at
/// `.custom(_:size:)` instead.
enum BaneFont {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }

    static func heading(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    /// Small uppercase tracked label, e.g. section eyebrows and stat labels.
    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    /// Tabular data — reps, weight, RPE, timers, durations.
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Small uppercase, wide-tracked mono label (mirrors `.bn-label` / `.bn-h3`).
struct BaneLabelStyle: ViewModifier {
    var size: CGFloat = 11
    func body(content: Content) -> some View {
        content
            .font(BaneFont.label(size))
            .tracking(1.4)
            .textCase(.uppercase)
    }
}

/// Tight, bold section heading (mirrors `.bn-h2`/`.bn-h3` used as titles).
struct BaneHeadingStyle: ViewModifier {
    var size: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .font(BaneFont.heading(size))
            .tracking(size <= 14 ? 1.2 : 0)
            .textCase(size <= 14 ? .uppercase : nil)
    }
}

extension View {
    func baneLabel(_ size: CGFloat = 11) -> some View {
        modifier(BaneLabelStyle(size: size))
    }

    func baneHeading(_ size: CGFloat = 14) -> some View {
        modifier(BaneHeadingStyle(size: size))
    }
}
