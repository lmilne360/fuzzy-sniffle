import SwiftUI

/// The two shells of the Bane design system: **Bane** (near-black + venom
/// green, the default) and **Batman** (colder navy-black + gold signal
/// accent). Same components and layout, different ``BanePalette``.
///
/// Ported from the design system built at claude.ai/design
/// (project `ff3cba02-4aea-4839-868e-62cca47e1d9a`) — see `styles.css` /
/// `themes/batman.css` there for the canonical color tokens this mirrors.
enum BaneTheme: String, CaseIterable, Identifiable, Sendable {
    case bane
    case batman

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bane: return "Bane"
        case .batman: return "Batman"
        }
    }

    var palette: BanePalette {
        switch self {
        case .bane: return .bane
        case .batman: return .batman
        }
    }
}

/// Shared storage contract for the theme preference, so Settings and the app
/// root agree on the key and default.
enum ThemePreferences {
    static let themeKey = "appTheme"
    static let fallback = BaneTheme.bane
}

/// One shell's full set of design tokens: surfaces, hairlines, text, and
/// semantic accents. Every color a themed view needs comes from here rather
/// than a hardcoded literal, so switching ``BaneTheme`` recolors everything
/// that reads from the environment.
struct BanePalette: Sendable {
    let void: Color
    let bg: Color
    let surface: Color
    let surface2: Color
    let surface3: Color

    let line: Color
    let lineStrong: Color

    let text: Color
    let text2: Color
    let text3: Color

    /// The single signal accent — venom green in Bane, gold in Batman. Used
    /// for actions, completion state, and live/running indicators.
    let accent: Color
    let accentBright: Color
    let accentDim: Color
    let accentWash: Color

    let amber: Color
    let danger: Color
    let steel: Color

    /// Foreground color for content painted directly on `accent` (a near-black
    /// in both shells, so the accent itself can move between green and gold).
    let onAccent: Color

    static let bane = BanePalette(
        void: Color(hex: 0x07090A),
        bg: Color(hex: 0x0B0E0F),
        surface: Color(hex: 0x121618),
        surface2: Color(hex: 0x191E21),
        surface3: Color(hex: 0x20272A),
        line: Color(hex: 0x242C30),
        lineStrong: Color(hex: 0x364146),
        text: Color(hex: 0xE8EEF0),
        text2: Color(hex: 0x9AA7AC),
        text3: Color(hex: 0x8B979D),
        accent: Color(hex: 0x9BF116),
        accentBright: Color(hex: 0xC7FF7A),
        accentDim: Color(hex: 0x5FA30A),
        accentWash: Color(hex: 0x9BF116).opacity(0.12),
        amber: Color(hex: 0xFFB020),
        danger: Color(hex: 0xFF4D2E),
        steel: Color(hex: 0x7FB3CC),
        onAccent: Color(hex: 0x0A0D06)
    )

    static let batman = BanePalette(
        void: Color(hex: 0x05060A),
        bg: Color(hex: 0x08090D),
        surface: Color(hex: 0x10131A),
        surface2: Color(hex: 0x171C25),
        surface3: Color(hex: 0x1E2531),
        line: Color(hex: 0x232B38),
        lineStrong: Color(hex: 0x35404F),
        text: Color(hex: 0xE9EDF3),
        text2: Color(hex: 0x9BA6B6),
        text3: Color(hex: 0x8A94A3),
        accent: Color(hex: 0xFFC61A),
        accentBright: Color(hex: 0xFFE08A),
        accentDim: Color(hex: 0xA87C00),
        accentWash: Color(hex: 0xFFC61A).opacity(0.12),
        amber: Color(hex: 0xFF9E2C),
        danger: Color(hex: 0xFF4A3D),
        steel: Color(hex: 0x6E8FB8),
        onAccent: Color(hex: 0x100C00)
    )
}

private struct BanePaletteKey: EnvironmentKey {
    static let defaultValue = BanePalette.bane
}

extension EnvironmentValues {
    /// The active theme's tokens. Set once at the app root from the stored
    /// ``ThemePreferences``; every design-system view reads it from here
    /// rather than taking a palette parameter.
    var banePalette: BanePalette {
        get { self[BanePaletteKey.self] }
        set { self[BanePaletteKey.self] = newValue }
    }
}

extension Color {
    /// Builds a `Color` from a packed `0xRRGGBB` literal, matching the hex
    /// tokens in the source design system's CSS.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
