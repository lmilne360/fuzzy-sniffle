import SwiftUI

/// Common rest-duration choices, shared by the settings screen and the
/// per-exercise override menu.
enum RestDurations {
    /// Preset lengths offered in pickers, in seconds.
    static let presets = [30, 45, 60, 90, 120, 150, 180, 240, 300]

    /// A compact `M:SS` / `Ss` label for a duration in seconds.
    static func label(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0
            ? "\(minutes) min"
            : String(format: "%d:%02d", minutes, remainder)
    }
}

/// The pinned rest-timer control shown along the bottom of the active workout
/// while a rest is counting down.
///
/// Ticks itself once a second to refresh the readout and to let the controller
/// fire its completion haptic, and offers extend / skip actions. Once the
/// countdown reaches zero it flips to a "Rest complete" state whose primary
/// action dismisses the bar.
struct RestTimerBar: View {
    /// Observed controller — reading its properties here tracks updates.
    let controller: RestTimerController

    @State private var now = Date()

    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let remaining = controller.remaining(at: now)
        let isDone = remaining == 0

        HStack(spacing: 14) {
            countdownRing(remaining: remaining, isDone: isDone)

            VStack(alignment: .leading, spacing: 2) {
                Text(isDone ? "Rest complete" : "Resting")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDone ? Color.green : .primary)
                if let name = controller.exerciseName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button {
                controller.extend(by: 30)
            } label: {
                Label("30s", systemImage: "goforward.30")
                    .labelStyle(.titleAndIcon)
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Add 30 seconds")

            Button {
                controller.stop()
            } label: {
                Text(isDone ? "Done" : "Skip")
                    .font(.callout.weight(.semibold))
                    .frame(minWidth: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(isDone ? "Dismiss rest timer" : "Skip rest")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .onReceive(ticker) { date in
            now = date
            controller.tick(date)
        }
    }

    /// A circular progress ring wrapped around the remaining-time readout.
    private func countdownRing(remaining: Int, isDone: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: controller.progress(at: now))
                .stroke(
                    isDone ? Color.green : Color.accentColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: remaining)

            Text(timeText(remaining))
                .font(.footnote.weight(.semibold).monospacedDigit())
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel(isDone ? "Rest complete" : "\(remaining) seconds remaining")
    }

    /// `M:SS` remaining-time formatting.
    private func timeText(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    let controller = RestTimerController()
    controller.start(seconds: 90, exerciseName: "Bench Press")
    return VStack {
        Spacer()
        RestTimerBar(controller: controller)
    }
}
