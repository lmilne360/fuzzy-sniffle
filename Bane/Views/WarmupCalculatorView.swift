import SwiftUI

/// A sheet that turns a working weight into a ladder of warm-up sets to prepend
/// to an exercise.
///
/// Seeded with a working weight (typically the exercise's heaviest logged set),
/// it recomputes the ramp live as the weight, ramp, or rounding change, previews
/// the result, and hands the chosen sets back to the caller via `onAdd`. The
/// chosen ramp and rounding persist via `AppStorage`; the bar weight is shared
/// with the plate calculator so the ladder never dips below the bar.
struct WarmupCalculatorView: View {
    /// Weight the ramp is built from — typically the heaviest working set.
    let initialWorkingWeight: Double
    /// Receives the generated warm-up sets when the user taps **Add**.
    let onAdd: ([WarmupCalculator.WarmupSet]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var workingWeight: Double

    @AppStorage(WarmupPreferences.schemeKey)
    private var schemeID = WarmupPreferences.fallbackSchemeID
    @AppStorage(WarmupPreferences.roundingKey)
    private var rounding = WarmupPreferences.fallbackRounding
    @AppStorage(PlatePreferences.barWeightKey)
    private var barWeight = PlatePreferences.fallbackBarWeight

    init(
        initialWorkingWeight: Double,
        onAdd: @escaping ([WarmupCalculator.WarmupSet]) -> Void
    ) {
        self.initialWorkingWeight = initialWorkingWeight
        self.onAdd = onAdd
        _workingWeight = State(initialValue: initialWorkingWeight)
    }

    private var scheme: WarmupPreferences.Scheme {
        WarmupPreferences.scheme(id: schemeID)
    }

    private var warmupSets: [WarmupCalculator.WarmupSet] {
        WarmupCalculator.warmupSets(
            workingWeight: workingWeight,
            scheme: scheme.steps,
            rounding: rounding,
            barWeight: barWeight
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                workingWeightSection
                schemeSection
                previewSection
                roundingSection
            }
            .navigationTitle("Warm-up Sets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(warmupSets)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(warmupSets.isEmpty)
                }
            }
        }
    }

    // MARK: - Sections

    private var workingWeightSection: some View {
        Section("Working weight") {
            HStack {
                TextField("0", value: $workingWeight, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title2.monospacedDigit())
                Stepper(
                    "Working weight",
                    value: $workingWeight,
                    in: 0...10_000,
                    step: rounding
                )
                .labelsHidden()
            }
        }
    }

    private var schemeSection: some View {
        Section("Ramp") {
            Picker("Ramp", selection: $schemeID) {
                ForEach(WarmupPreferences.schemes) { scheme in
                    Text(scheme.name).tag(scheme.id)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        Section("Warm-up sets") {
            if warmupSets.isEmpty {
                Text("Enter a working weight above the bar to build a ramp.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(Array(warmupSets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text("W\(index + 1)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .frame(width: 30, height: 26)
                            .background(Color.orange.opacity(0.2), in: Circle())
                            .foregroundStyle(Color.orange)
                        Text("\(percentLabel(set.percentage)) of working")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Spacer()
                        Text("\(set.reps) × \(Formatting.plate(set.weight))")
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var roundingSection: some View {
        Section("Round to") {
            Picker("Round to", selection: $rounding) {
                ForEach(WarmupPreferences.roundingPresets, id: \.self) { increment in
                    Text(Formatting.plate(increment)).tag(increment)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// A whole-number percent label for a `0...1` fraction (`40%`).
    private func percentLabel(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }
}

#Preview {
    WarmupCalculatorView(initialWorkingWeight: 185) { _ in }
}
