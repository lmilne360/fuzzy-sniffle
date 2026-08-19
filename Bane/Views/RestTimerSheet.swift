import SwiftUI

/// The full rest-countdown modal shown over the workout list between sets —
/// a dimmed scrim behind a bottom sheet with the ``BaneRestRing`` dial, a
/// "next up" preview, symmetric adjust controls, and skip. Matches the
/// design system's `RestTimerSheet` component.
///
/// Tapping the scrim, tapping the grabber, or swiping the sheet down doesn't
/// cancel the rest — it hands off to `onMinimize`, which the owning
/// `ActiveWorkoutView` uses to swap this modal for ``RestTimerMinimizedBar``
/// while the same `RestTimerController` keeps running underneath either
/// presentation.
struct RestTimerSheet: View {
    let controller: RestTimerController
    let now: Date
    /// Name of the exercise the next set belongs to, or `nil` when this is
    /// the workout's last set.
    let nextExercise: String?
    /// The next set's 1-based position within its exercise.
    let nextSet: Int?
    /// Total sets in that exercise, for a "Set 4 of 4" readout.
    let nextSetTotal: Int?
    let onMinimize: () -> Void

    /// Seconds remaining at/below which the sheet flips to its amber "almost
    /// done" state — matches the design system's `urgentAt` default, and is
    /// shared with ``RestTimerMinimizedBar`` so both presentations agree on
    /// when to go amber.
    static let urgentAt = 10
    /// Step applied by the -/+ adjust buttons.
    private static let adjustSeconds = 15

    @Environment(\.banePalette) private var palette
    @State private var dragOffset: CGFloat = 0
    /// Whether the -/+ adjust row is swapped for a direct-entry duration
    /// field — for jumping straight to a length (e.g. 90s to 5 minutes)
    /// rather than nudging by ``adjustSeconds`` repeatedly.
    @State private var isEnteringExactDuration = false
    @State private var exactDurationSeconds: Int?
    @FocusState private var isExactDurationFieldFocused: Bool

    private var remaining: Int { controller.remaining(at: now) }
    private var isDone: Bool { remaining == 0 }
    private var isUrgent: Bool { !isDone && remaining <= Self.urgentAt }

    var body: some View {
        ZStack(alignment: .bottom) {
            palette.void.opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onMinimize)
                .accessibilityLabel("Minimize rest timer")
                .accessibilityAddTraits(.isButton)

            card
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { dragOffset = max(0, $0.translation.height) }
                        .onEnded { value in
                            if value.translation.height > 60 {
                                onMinimize()
                            }
                            withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                        }
                )
        }
    }

    private var card: some View {
        VStack(spacing: 18) {
            grabber
            BaneRestRing(
                remaining: remaining,
                total: controller.totalSeconds,
                label: isUrgent ? "Almost" : "Rest",
                size: 164,
                tone: isUrgent ? .amber : .venom
            )
            if let nextExercise {
                nextSetLabel(nextExercise)
            }
            actions
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .background(palette.surface2)
        .clipShape(
            .rect(topLeadingRadius: 22, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 22)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(isUrgent ? palette.amber : palette.accent)
                .frame(height: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 40, y: -10)
    }

    private var grabber: some View {
        Button(action: onMinimize) {
            Capsule()
                .fill(palette.lineStrong)
                .frame(width: 38, height: 4)
                .frame(width: 64, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Minimize rest timer")
    }

    private func nextSetLabel(_ exercise: String) -> some View {
        (Text("Next · ")
            + Text(exercise).fontWeight(.semibold).foregroundStyle(palette.text2)
            + Text(nextSetSuffix))
            .baneLabel()
            .foregroundStyle(palette.text3)
            .multilineTextAlignment(.center)
            .accessibilityLabel("Next: \(exercise)\(nextSetSuffix)")
    }

    private var nextSetSuffix: String {
        guard let nextSet else { return "" }
        guard let nextSetTotal else { return " · Set \(nextSet)" }
        return " · Set \(nextSet) of \(nextSetTotal)"
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if isEnteringExactDuration {
                exactDurationRow
            } else {
                HStack(spacing: 10) {
                    Button("Reset") {
                        controller.restart()
                    }
                    .buttonStyle(.bane(.secondary, block: true))
                    .accessibilityLabel("Reset rest to \(Self.formattedDuration(controller.totalSeconds))")

                    Button("\u{2212}\(Self.adjustSeconds)s") {
                        controller.extend(by: -Self.adjustSeconds)
                    }
                    .buttonStyle(.bane(.secondary, block: true))
                    .disabled(isDone)
                    .accessibilityLabel("Subtract \(Self.adjustSeconds) seconds")

                    Button("+\(Self.adjustSeconds)s") {
                        controller.extend(by: Self.adjustSeconds)
                    }
                    .buttonStyle(.bane(.secondary, block: true))
                    .accessibilityLabel("Add \(Self.adjustSeconds) seconds")
                }
            }

            HStack(spacing: 10) {
                keyboardToggle

                Button(isDone ? "Done" : "Skip") {
                    if isDone {
                        controller.stop()
                    } else {
                        controller.skip()
                    }
                }
                .buttonStyle(.bane(.primary, block: true))
                .accessibilityLabel(isDone ? "Dismiss rest timer" : "Skip rest")
            }
        }
    }

    private var keyboardToggle: some View {
        Button {
            isEnteringExactDuration.toggle()
            if isEnteringExactDuration {
                exactDurationSeconds = nil
                isExactDurationFieldFocused = true
            }
        } label: {
            Image(systemName: isEnteringExactDuration ? "keyboard.chevron.compact.down" : "keyboard")
                .font(.body)
                .frame(width: BaneButtonSize.medium.height, height: BaneButtonSize.medium.height)
        }
        .buttonStyle(.bane(.secondary))
        .accessibilityLabel(isEnteringExactDuration ? "Hide exact duration entry" : "Enter exact rest duration")
    }

    private var exactDurationRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                TextField("sec", value: $exactDurationSeconds, format: .number)
                    .keyboardType(.numberPad)
                    .focused($isExactDurationFieldFocused)
                    .font(BaneFont.mono(15, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.text)
                    .onSubmit(applyExactDuration)
                Text("sec")
                    .baneLabel()
                    .foregroundStyle(palette.text3)
            }
            .padding(.horizontal, 12)
            .frame(height: BaneButtonSize.medium.height)
            .frame(maxWidth: .infinity)
            .background(palette.surface3, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .accessibilityLabel("Exact rest duration in seconds")

            Button("Set") {
                applyExactDuration()
            }
            .buttonStyle(.bane(.primary, block: true))
            .disabled((exactDurationSeconds ?? 0) <= 0)
            .accessibilityLabel("Set rest duration")
        }
    }

    private func applyExactDuration() {
        guard let exactDurationSeconds, exactDurationSeconds > 0 else { return }
        controller.setDuration(seconds: exactDurationSeconds)
        isEnteringExactDuration = false
        self.exactDurationSeconds = nil
    }

    /// `M:SS` duration formatting, matching ``BaneRestRing``'s readout.
    private static func formattedDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    let controller = RestTimerController()
    controller.start(seconds: 90, exerciseName: "Bench Press", exerciseID: nil)
    return RestTimerSheet(
        controller: controller,
        now: Date(),
        nextExercise: "Chest Dip",
        nextSet: 4,
        nextSetTotal: 4,
        onMinimize: {}
    )
}
