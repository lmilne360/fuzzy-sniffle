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
/// Driven by `now`, which the owning `ActiveWorkoutView` advances on its one
/// shared tick (also driving the session clock) — this view has no timer of
/// its own. Offers extend / skip actions; once the countdown reaches zero it
/// flips to a "Rest complete" state whose primary action dismisses the bar.
struct RestTimerBar: View {
    /// Observed controller — reading its properties here tracks updates.
    let controller: RestTimerController
    /// The shared tick's current time, supplied by the owning view.
    let now: Date

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
                controller.extend(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Subtract 15 seconds")
            .disabled(isDone)

            Button {
                controller.extend(by: 30)
            } label: {
                Label("30s", systemImage: "goforward.30")
                    .labelStyle(.titleAndIcon)
                    .font(.callout.weight(.medium))
                    .fixedSize()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Add 30 seconds")

            Button {
                if isDone {
                    controller.stop()
                } else {
                    controller.skip()
                }
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
    controller.start(seconds: 90, exerciseName: "Bench Press", exerciseID: nil)
    return VStack {
        Spacer()
        RestTimerBar(controller: controller, now: Date())
    }
}
