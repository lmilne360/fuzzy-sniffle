import SwiftUI

/// Pre-formatted recap shown in ``DeleteWorkoutDialog`` before a completed
/// workout is deleted — keeps the dialog a pure display component, matching
/// the design system's `DeleteWorkoutSummary` shape.
struct DeleteWorkoutSummary {
    var name: String
    var date: String
    var duration: String?
    var volume: String
    var sets: Int
}

/// Destructive confirm shown over workout history before deleting a
/// completed session — recaps name, date, duration, volume, and set count
/// rather than deleting silently on swipe. Matches the design system's
/// `DeleteWorkoutDialog`. Paired with ``UndoToast`` for a grace window after
/// the delete commits.
struct DeleteWorkoutDialog: View {
    let workout: DeleteWorkoutSummary
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @Environment(\.banePalette) private var palette

    var body: some View {
        ZStack {
            palette.void.opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            card
                .padding(.horizontal, 20)
        }
        .accessibilityLabel("Delete \(workout.name)")
    }

    private var card: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Delete this workout?")
                    .font(BaneFont.heading(19))
                    .foregroundStyle(palette.text)
                Text("The session is removed from your history and its volume stops counting toward your trends.")
                    .font(.subheadline)
                    .foregroundStyle(palette.text2)
                recap
            }
            .padding(22)

            HStack(spacing: 10) {
                Button("Keep", action: onCancel)
                    .buttonStyle(.bane(.secondary, block: true))
                Button("Delete", action: onConfirm)
                    .buttonStyle(DeleteWorkoutConfirmButtonStyle())
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .background(palette.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.lineStrong, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 14)
        .frame(maxWidth: 380)
    }

    private var recap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workout.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.text)
            HStack(spacing: 14) {
                Text(workout.date)
                if let duration = workout.duration {
                    Text(duration)
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.text2)
                }
                Text("\(workout.sets)").fontWeight(.semibold).foregroundStyle(palette.text2)
                    + Text(" sets")
                Text(workout.volume)
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text2)
            }
            .font(BaneFont.mono(11))
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(palette.text3)
        }
        .padding(14)
        .background(palette.void)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(palette.line, lineWidth: 1)
        )
    }
}

/// Solid danger button matching `.bn-dialog__confirm` — a filled treatment
/// distinct from ``BaneButtonKind/danger``'s outlined style, used here so the
/// dialog's destructive action reads as the primary action.
private struct DeleteWorkoutConfirmButtonStyle: ButtonStyle {
    @Environment(\.banePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .tracking(1.1)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(configuration.isPressed ? palette.danger.opacity(0.85) : palette.danger)
            .foregroundStyle(Color(hex: 0x1A0400))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
