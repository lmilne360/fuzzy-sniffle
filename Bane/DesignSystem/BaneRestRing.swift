import SwiftUI

/// Circular rest countdown dial matching `.bn-ring`: a track ring, an accent
/// arc that sweeps down as time elapses, and a centered mm:ss readout.
///
/// Not yet wired into the live rest-timer bar — `RestTimerBar`/
/// `RestTimerController` have in-flight work on the same surface (ba-b4n).
/// This is the design-system counterpart ready for that integration once it
/// lands.
struct BaneRestRing: View {
    var remaining: Int
    var total: Int
    var label: String = "Rest"
    var size: CGFloat = 168

    @Environment(\.banePalette) private var palette

    private var progress: Double {
        guard total > 0 else { return 0 }
        return max(0, min(1, Double(remaining) / Double(total)))
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
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 7, lineCap: .butt))
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
