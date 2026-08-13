import SwiftUI

/// A logged set — reps × weight × RPE plus a completion toggle — matching
/// `.bn-setrow`: a compact grid row that washes venom-green when done.
struct BaneSetRow: View {
    var index: Int
    var reps: String
    var weight: String
    var weightUnit: String
    var rpe: String?
    var done: Bool
    var onToggle: () -> Void

    @Environment(\.banePalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(BaneFont.mono(12, weight: .semibold))
                .foregroundStyle(palette.text3)
                .frame(width: 26)

            cell(k: "Reps", v: reps)
            cell(k: "Weight (\(weightUnit))", v: weight)
            cell(k: "RPE", v: rpe ?? "—")
                .frame(width: 54)

            Button(action: onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(done ? .clear : palette.lineStrong, lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(done ? palette.accent : .clear)
                        )
                        .frame(width: 26, height: 26)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.onAccent)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Mark set incomplete" : "Mark set complete")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ZStack {
                palette.surface2
                if done { palette.accentWash }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(done ? palette.accent.opacity(0.32) : palette.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func cell(k: String, v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k)
                .font(BaneFont.mono(10))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(palette.text3)
                .lineLimit(1)
            Text(v)
                .font(BaneFont.mono(15, weight: .medium))
                .foregroundStyle(palette.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
