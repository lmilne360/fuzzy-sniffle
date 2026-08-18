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

/// The compact, persistent bottom bar shown while resting once
/// ``RestTimerSheet`` has been minimized (scrim tap, grabber tap, or
/// swipe-down) — remaining time, exercise name, and nothing else. Adjust /
/// skip controls live on the full sheet; tapping anywhere on this bar
/// reopens it via `onExpand`, so the list stays interactive without losing
/// access to those controls.
///
/// Driven by `now`, which the owning `ActiveWorkoutView` advances on its one
/// shared tick (also driving the session clock) — this view has no timer of
/// its own.
struct RestTimerMinimizedBar: View {
    /// Observed controller — reading its properties here tracks updates.
    let controller: RestTimerController
    /// The shared tick's current time, supplied by the owning view.
    let now: Date
    let onExpand: () -> Void

    @Environment(\.banePalette) private var palette

    private var remaining: Int { controller.remaining(at: now) }
    private var isDone: Bool { remaining == 0 }
    private var isUrgent: Bool { !isDone && remaining <= RestTimerSheet.urgentAt }

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 14) {
                miniRing

                VStack(alignment: .leading, spacing: 2) {
                    Text(isDone ? "Rest complete" : "Resting")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isDone ? palette.accent : palette.text)
                    if let name = controller.exerciseName {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(palette.text3)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.text3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.bar)
        .accessibilityLabel(isDone ? "Rest complete" : "Resting, \(remaining) seconds remaining")
        .accessibilityHint("Reopens the rest timer")
    }

    /// A small progress ring wrapped around the remaining-time readout.
    private var miniRing: some View {
        ZStack {
            Circle()
                .stroke(palette.surface3, lineWidth: 4)
            Circle()
                .trim(from: 0, to: 1 - controller.progress(at: now))
                .stroke(
                    isUrgent ? palette.amber : palette.accent,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: remaining)

            Text(timeText(remaining))
                .font(BaneFont.mono(11, weight: .semibold))
                .foregroundStyle(palette.text)
        }
        .frame(width: 36, height: 36)
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
        RestTimerMinimizedBar(controller: controller, now: Date(), onExpand: {})
    }
}
