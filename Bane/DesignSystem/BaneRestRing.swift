import SwiftUI

/// Circular rest countdown dial matching `.bn-ring`: a track ring, an accent
/// arc that sweeps down as time elapses, and a centered mm:ss readout.
///
/// Wired into the live rest timer via `RestTimerSheet` — `tone` drives the
/// spec's amber/venom arc color for the "almost done" urgent state.
struct BaneRestRing: View {
    /// Ring arc color — amber signals the final seconds, matching `.bn-ring`'s
    /// `tone` prop in the design system.
    enum Tone {
        case venom, amber
    }

    var remaining: Int
    var total: Int
    var label: String = "Rest"
    var size: CGFloat = 168
    var tone: Tone = .venom

    @Environment(\.banePalette) private var palette

    private var progress: Double {
        guard total > 0 else { return 0 }
        return max(0, min(1, Double(remaining) / Double(total)))
    }

    private var ringColor: Color {
        switch tone {
        case .venom: return palette.accent
        case .amber: return palette.amber
        }
    }

    private var timeText: String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.surface3, lineWidth: 7)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Text(timeText)
                    .font(BaneFont.display(30))
                    .foregroundStyle(palette.text)
                Text(label).baneLabel().foregroundStyle(palette.text3)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.25), value: progress)
    }
}
