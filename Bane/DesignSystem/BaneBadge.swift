import SwiftUI

/// Semantic color for a ``BaneBadge`` — mirrors `.bn-badge--venom/amber/danger/steel/muted/solid`.
enum BaneBadgeKind {
    case accent, amber, danger, steel, muted, solid
}

/// Small dot + uppercase-mono status pill matching `.bn-badge`.
struct BaneBadge: View {
    var text: String
    var kind: BaneBadgeKind = .accent
    /// Whether to show the leading status dot. Defaults to `nil`, which preserves
    /// the historical behavior of showing a dot for every non-solid tone and
    /// hiding it for `.solid` — pass `true`/`false` to set dot independent of tone.
    var dot: Bool?

    @Environment(\.banePalette) private var palette

    private var showDot: Bool { dot ?? (kind != .solid) }

    var body: some View {
        HStack(spacing: 6) {
            if showDot {
                Circle().fill(foreground).frame(width: 5, height: 5)
            }
            Text(text)
                .font(BaneFont.mono(10, weight: .medium))
                .tracking(1.2)
                .textCase(.uppercase)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }

    private var foreground: Color {
        switch kind {
        case .accent: return palette.accent
        case .amber: return palette.amber
        case .danger: return palette.danger
        case .steel: return palette.steel
        case .muted: return palette.text3
        case .solid: return palette.onAccent
        }
    }

    private var background: Color {
        switch kind {
        case .accent: return palette.accentWash
        case .amber: return palette.amber.opacity(0.1)
        case .danger: return palette.danger.opacity(0.1)
        case .steel: return palette.steel.opacity(0.1)
        case .muted: return palette.surface2
        case .solid: return palette.accent
        }
    }

    private var borderColor: Color {
        switch kind {
        case .accent: return palette.accent.opacity(0.35)
        case .amber: return palette.amber.opacity(0.35)
        case .danger: return palette.danger.opacity(0.35)
        case .steel: return palette.steel.opacity(0.35)
        case .muted: return palette.line
        case .solid: return .clear
        }
    }
}
