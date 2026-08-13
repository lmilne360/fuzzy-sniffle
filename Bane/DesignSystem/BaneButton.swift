import SwiftUI

/// Visual weight of a ``BaneButtonStyle`` — mirrors `.bn-btn--primary` /
/// `--secondary` / `--ghost` / `--danger`.
enum BaneButtonKind {
    case primary, secondary, ghost, danger
}

enum BaneButtonSize {
    case small, medium, large

    var height: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 44
        case .large: return 56
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 18
        case .large: return 26
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .small: return 11
        case .medium: return 13
        case .large: return 15
        }
    }
}

/// Bold uppercase, tracked button matching the source system's `.bn-btn`
/// family: solid accent primary, outlined secondary, borderless ghost, and an
/// outlined danger variant for destructive actions.
struct BaneButtonStyle: ButtonStyle {
    var kind: BaneButtonKind = .primary
    var size: BaneButtonSize = .medium
    var isBlock: Bool = false

    @Environment(\.banePalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .bold))
            .tracking(1.1)
            .textCase(.uppercase)
            .lineLimit(1)
            .frame(maxWidth: isBlock ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(background(pressed: configuration.isPressed))
            .foregroundStyle(foreground(pressed: configuration.isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(borderColor(pressed: configuration.isPressed), lineWidth: kind == .secondary || kind == .danger ? 1 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .opacity(isEnabled ? 1 : 0.38)
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: return pressed ? palette.accentBright : palette.accent
        case .secondary: return .clear
        case .ghost: return pressed ? palette.surface2 : .clear
        case .danger: return pressed ? palette.danger.opacity(0.12) : .clear
        }
    }

    private func foreground(pressed: Bool) -> Color {
        switch kind {
        case .primary: return palette.onAccent
        case .secondary: return pressed ? palette.accent : palette.text
        case .ghost: return palette.text2
        case .danger: return palette.danger
        }
    }

    private func borderColor(pressed: Bool) -> Color {
        switch kind {
        case .secondary: return pressed ? palette.accent : palette.lineStrong
        case .danger: return palette.danger.opacity(0.42)
        default: return .clear
        }
    }
}

extension ButtonStyle where Self == BaneButtonStyle {
    static func bane(_ kind: BaneButtonKind = .primary, size: BaneButtonSize = .medium, block: Bool = false) -> BaneButtonStyle {
        BaneButtonStyle(kind: kind, size: size, isBlock: block)
    }
}
