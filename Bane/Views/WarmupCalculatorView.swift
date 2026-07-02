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
    private var rounding = WarmupPreferences.fallbackRounding(for: WeightPreferences.fallback)
    @AppStorage(PlatePreferences.barWeightKey)
    private var barWeight = PlatePreferences.fallbackBarWeight

    /// The unit weights are displayed and entered in. The working weight and bar
    /// stay canonical pounds; only the on-screen numbers, the rounding increment,
    /// and the ladder handed back convert (ba-2qm).
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback

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

    /// The stored rounding clamped to a preset valid for the current unit, so an
    /// increment chosen in one unit never drives the ladder — or leaves the
    /// picker without a selection — after switching units (ba-2qm).
    private var effectiveRounding: Double {
        let presets = WarmupPreferences.roundingPresets(for: weightUnit)
        return presets.contains(rounding)
            ? rounding
            : WarmupPreferences.fallbackRounding(for: weightUnit)
    }

    /// The warm-up ladder in canonical pounds, ready to hand back via `onAdd`.
    ///
    /// The ramp is built and rounded in the *displayed* unit — so kg users get
    /// kg-native rungs — then each weight converts back to the pound scale the
    /// data model stores (ba-2qm).
    private var warmupSets: [WarmupCalculator.WarmupSet] {
        WarmupCalculator.warmupSets(
            workingWeight: weightUnit.fromPounds(workingWeight),
            scheme: scheme.steps,
            rounding: effectiveRounding,
            barWeight: weightUnit.fromPounds(barWeight)
        ).map { set in
            WarmupCalculator.WarmupSet(
                percentage: set.percentage,
                weight: weightUnit.toPounds(set.weight),
                reps: set.reps
            )
        }
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
        Section("Working weight (\(weightUnit.abbreviation))") {
            HStack {
                TextField("0", value: $workingWeight.weightDisplay(in: weightUnit), format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title2.monospacedDigit())
                Stepper(
                    "Working weight",
                    value: $workingWeight,
                    in: 0...10_000,
                    step: weightUnit.toPounds(effectiveRounding)
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
                        Text("\(set.reps) × \(WeightFormat.weight(set.weight, in: weightUnit))")
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var roundingSection: some View {
        Section("Round to (\(weightUnit.abbreviation))") {
            Picker("Round to", selection: roundingSelection) {
                ForEach(WarmupPreferences.roundingPresets(for: weightUnit), id: \.self) { increment in
                    Text(Formatting.plate(increment)).tag(increment)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// Drives the rounding picker off ``effectiveRounding`` so the segmented
    /// control always shows a valid selection, even right after a unit switch
    /// leaves the stored increment outside the new unit's presets (ba-2qm).
    private var roundingSelection: Binding<Double> {
        Binding(get: { effectiveRounding }, set: { rounding = $0 })
    }

    /// A whole-number percent label for a `0...1` fraction (`40%`).
    private func percentLabel(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }
}

#Preview {
    WarmupCalculatorView(initialWorkingWeight: 185) { _ in }
}
