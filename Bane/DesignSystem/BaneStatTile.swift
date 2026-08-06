import SwiftUI

/// Direction of a ``BaneStatTile`` trend delta, if any.
enum BaneStatTrend {
    case up, down, flat
}

/// Numeric readout tile matching `.bn-stat`: an uppercase mono label, a large
/// tabular value with optional unit, and an optional trend delta line.
struct BaneStatTile: View {
    var label: String
    var value: String
    var unit: String?
    var delta: String?
    var trend: BaneStatTrend = .flat

    @Environment(\.banePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).baneLabel().foregroundStyle(palette.text3)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(value)
                    .font(BaneFont.display(34))
                    .foregroundStyle(palette.text)
                if let unit {
                    Text(unit)
                        .font(BaneFont.mono(12))
                        .foregroundStyle(palette.text2)
                }
            }

            if let delta {
                Text(delta)
                    .font(BaneFont.mono(11))
                    .foregroundStyle(deltaColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var deltaColor: Color {
        switch trend {
        case .up: return palette.accent
        case .down: return palette.danger
        case .flat: return palette.text3
        }
    }
}
