import SwiftUI

/// Time-boxed undo affordance shown after a destructive action commits —
/// tapping the action within the window reverses it. Matches the design
/// system's `UndoToast`. Paired with ``DeleteWorkoutDialog``.
struct UndoToast: View {
    let message: String
    /// Seconds left before the undo window closes; `nil` hides the countdown.
    var seconds: Int?
    var actionLabel: String = "Undo"
    let onAction: () -> Void

    @Environment(\.banePalette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(palette.danger)
                    .frame(width: 6, height: 6)
                Text(message)
                if let seconds {
                    Text("\(seconds)s")
                        .foregroundStyle(palette.text3)
                }
            }
            .font(BaneFont.mono(11))
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(palette.text2)

            Spacer(minLength: 8)

            Button(action: onAction) {
                Text(actionLabel)
                    .font(BaneFont.mono(11, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(palette.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(palette.lineStrong, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .accessibilityElement(children: .combine)
    }
}
