import SwiftUI

/// Stepper input for reps/weight/RPE matching `.bn-numf`: an uppercase mono
/// label above a bordered control with –/+ step buttons flanking a centered
/// bold value.
struct BaneNumberField: View {
    var label: String?
    @Binding var value: Double
    var unit: String?
    var step: Double = 1
    var formatter: (Double) -> String = { $0.formatted(.number.precision(.fractionLength(0...1))) }

    @Environment(\.banePalette) private var palette
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label).baneLabel().foregroundStyle(palette.text3)
            }
            HStack(spacing: 0) {
                stepButton(systemImage: "minus") { value = max(0, value - step) }

                TextField("0", value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($isFocused)
                    .font(BaneFont.heading(20))
                    .monospacedDigit()
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity)

                if let unit {
                    Text(unit)
                        .font(BaneFont.mono(11))
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(palette.text3)
                        .padding(.trailing, 12)
                }

                stepButton(systemImage: "plus") { value += step }
            }
            .frame(height: 48)
            .background(palette.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(isFocused ? palette.accent : palette.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.text2)
                .frame(width: 44)
                .frame(maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}
