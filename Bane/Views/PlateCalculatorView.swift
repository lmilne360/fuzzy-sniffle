import SwiftUI

/// A sheet that breaks a target barbell weight down into the plates to hang on
/// each side of the bar.
///
/// Seeded with a starting weight (e.g. the weight of the set it was opened
/// from), it recomputes live as the target, bar, or available plates change.
/// Bar weight and the on-hand plate set persist via `AppStorage` so the setup
/// carries across sessions.
struct PlateCalculatorView: View {
    /// Weight the sheet opens on — typically the set's logged weight.
    let initialTarget: Double

    @Environment(\.dismiss) private var dismiss

    @State private var target: Double
    @State private var isEditingPlates = false

    @AppStorage(PlatePreferences.barWeightKey)
    private var barWeight = PlatePreferences.fallbackBarWeight
    @AppStorage(PlatePreferences.availablePlatesKey)
    private var availablePlatesRaw = PlatePreferences.encode(PlatePreferences.fallbackPlates)

    init(initialTarget: Double) {
        self.initialTarget = initialTarget
        _target = State(initialValue: initialTarget)
    }

    private var plates: [Double] {
        PlatePreferences.decode(availablePlatesRaw)
    }

    private var loadout: PlateCalculator.Loadout {
        PlateCalculator.solve(target: target, barWeight: barWeight, plates: plates)
    }

    var body: some View {
        NavigationStack {
            Form {
                targetSection
                barSection
                breakdownSection
                platesSection
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isEditingPlates) {
                AvailablePlatesEditor(availablePlatesRaw: $availablePlatesRaw)
            }
        }
    }

    // MARK: - Sections

    private var targetSection: some View {
        Section("Target weight") {
            HStack {
                TextField("0", value: $target, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title2.monospacedDigit())
                Stepper(
                    "Target weight",
                    value: $target,
                    in: 0...10_000,
                    step: smallestPlateStep
                )
                .labelsHidden()
            }
        }
    }

    private var barSection: some View {
        Section("Bar") {
            Picker("Bar weight", selection: $barWeight) {
                ForEach(PlatePreferences.barPresets, id: \.self) { weight in
                    Text(weight == 0 ? "None" : Formatting.plate(weight))
                        .tag(weight)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var breakdownSection: some View {
        Section("Per side") {
            if loadout.isBelowBar {
                Label(
                    "Target is below the \(Formatting.plate(barWeight)) bar.",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.secondary)
                .font(.callout)
            } else if loadout.perSide.isEmpty {
                Text("Just the bar — no plates needed.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                PlateStackView(placements: loadout.perSide)
                    .padding(.vertical, 4)

                ForEach(loadout.perSide) { placement in
                    HStack {
                        Text("\(placement.count) ×")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(Formatting.plate(placement.plate))
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Formatting.plate(placement.plate * Double(placement.count))) / side")
                            .foregroundStyle(.secondary)
                            .font(.callout.monospacedDigit())
                    }
                }
            }

            if !loadout.isExact && !loadout.isBelowBar {
                Label(
                    "Closest with your plates: \(Formatting.plate(loadout.achieved)) "
                        + "(\(Formatting.plate(loadout.remainder)) short).",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var platesSection: some View {
        Section {
            Button {
                isEditingPlates = true
            } label: {
                HStack {
                    Label("Available plates", systemImage: "slider.horizontal.3")
                    Spacer()
                    Text(plates.map(Formatting.plate).joined(separator: ", "))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
    }

    /// Stepper increment: the smallest plate loads ±2× that plate onto the bar.
    private var smallestPlateStep: Double {
        (plates.min().map { $0 * 2 }) ?? 5
    }
}

// MARK: - Plate stack visualization

/// A simple side-on rendering of the plates on one side of the bar, heaviest
/// nearest the collar. Widths scale with denomination so the stack reads at a
/// glance.
private struct PlateStackView: View {
    let placements: [PlateCalculator.Placement]

    private var heaviest: Double {
        placements.map(\.plate).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            // The bar sleeve.
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 16, height: 6)

            ForEach(placements) { placement in
                ForEach(0..<placement.count, id: \.self) { _ in
                    plate(placement.plate)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func plate(_ weight: Double) -> some View {
        let scale = 0.45 + 0.55 * (weight / heaviest)
        return RoundedRectangle(cornerRadius: 3)
            .fill(Color.accentColor.gradient)
            .frame(width: 14, height: 54 * scale)
            .overlay(
                Text(Formatting.plate(weight))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
            )
    }

    private var accessibilitySummary: String {
        let parts = placements.map {
            "\($0.count) times \(Formatting.plate($0.plate))"
        }
        return "Per side: " + parts.joined(separator: ", ")
    }
}

// MARK: - Available plates editor

/// A sheet for toggling which plate denominations are on hand.
private struct AvailablePlatesEditor: View {
    @Binding var availablePlatesRaw: String

    @Environment(\.dismiss) private var dismiss

    private var selected: Set<Double> {
        Set(PlatePreferences.decode(availablePlatesRaw))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(PlatePreferences.selectablePlates, id: \.self) { plate in
                        Button {
                            toggle(plate)
                        } label: {
                            HStack {
                                Text(Formatting.plate(plate))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selected.contains(plate) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Plates you have on hand. The calculator only loads these.")
                }
            }
            .navigationTitle("Available Plates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Flips a denomination on or off, keeping at least one plate selected so
    /// the calculator always has something to work with.
    private func toggle(_ plate: Double) {
        var plates = selected
        if plates.contains(plate) {
            guard plates.count > 1 else { return }
            plates.remove(plate)
        } else {
            plates.insert(plate)
        }
        availablePlatesRaw = PlatePreferences.encode(Array(plates))
    }
}

#Preview {
    PlateCalculatorView(initialTarget: 185)
}
