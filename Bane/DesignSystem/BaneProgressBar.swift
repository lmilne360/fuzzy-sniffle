import SwiftUI

/// Fill color for a ``BaneProgressBar`` — mirrors `.bn-prog__fill--amber/danger/steel`.
enum BaneProgressKind {
    case accent, amber, danger, steel
}

/// Thin track-and-fill progress indicator matching `.bn-prog`, with optional
/// uppercase mono meta labels above the track (e.g. "Session" / "3 of 5").
struct BaneProgressBar: View {
    var progress: Double
    var leadingLabel: String?
    var trailingLabel: String?
    var kind: BaneProgressKind = .accent

    @Environment(\.banePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if leadingLabel != nil || trailingLabel != nil {
                HStack {
                    if let leadingLabel {
                        Text(leadingLabel).baneLabel().foregroundStyle(palette.text3)
                    }
                    Spacer()
                    if let trailingLabel {
                        Text(trailingLabel).baneLabel().foregroundStyle(palette.text3)
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.surface3)
                    Capsule()
                        .fill(fillColor)
                        .frame(width: geo.size.width * max(0, min(1, progress)))
                }
            }
            .frame(height: 6)
        }
    }

    private var fillColor: Color {
        switch kind {
        case .accent: return palette.accent
        case .amber: return palette.amber
        case .danger: return palette.danger
        case .steel: return palette.steel
        }
    }
}
