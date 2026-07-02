import SwiftData
import SwiftUI

/// Form for recording a new ``BodyMeasurement`` snapshot.
///
/// Every numeric field is optional: the user fills in whatever they measured and
/// blanks are left `nil`. Saving is disabled until at least one value is entered
/// so empty snapshots never reach the store. Values are typed as free text and
/// parsed on save, keeping the decimal keyboard forgiving of partial input.
struct AddMeasurementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    /// Raw text per field, keyed by ``MeasurementFieldSpec/label``.
    @State private var text: [String: String] = [:]
    @State private var notes = ""

    /// The unit bodyweight is entered in; stored back as canonical pounds.
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback

    var body: some View {
        Form {
            Section("Date") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .labelsHidden()
            }

            Section("Body") {
                fieldRow(MeasurementFieldSpec.weight)
                fieldRow(MeasurementFieldSpec.bodyFat)
            }

            Section("Circumferences") {
                ForEach(MeasurementFieldSpec.circumferences) { spec in
                    fieldRow(spec)
                }
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(1...4)
            }
        }
        .navigationTitle("New Measurement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!hasAnyValue)
            }
        }
    }

    private func fieldRow(_ spec: MeasurementFieldSpec) -> some View {
        HStack {
            Text(spec.label)
            Spacer()
            TextField(spec.placeholder, text: binding(for: spec))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
            if let unit = unitLabel(for: spec) {
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The unit suffix shown beside a field: the live weight unit for bodyweight,
    /// otherwise the spec's own fixed unit (e.g. `%`).
    private func unitLabel(for spec: MeasurementFieldSpec) -> String? {
        spec.isWeight ? weightUnit.abbreviation : spec.unit
    }

    private func binding(for spec: MeasurementFieldSpec) -> Binding<String> {
        Binding(
            get: { text[spec.label] ?? "" },
            set: { text[spec.label] = $0 }
        )
    }

    /// `true` once any field parses to a number — mirrors the model's non-empty
    /// contract so the Save button and the store agree.
    private var hasAnyValue: Bool {
        MeasurementFieldSpec.all.contains { parsedValue(for: $0) != nil }
    }

    /// Parses a field's raw text into a number, treating blank/garbage as `nil`.
    private func parsedValue(for spec: MeasurementFieldSpec) -> Double? {
        guard let raw = text[spec.label]?.trimmingCharacters(in: .whitespaces),
              !raw.isEmpty else { return nil }
        return Double(raw)
    }

    private func save() {
        let measurement = BodyMeasurement(date: date, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        for spec in MeasurementFieldSpec.all {
            // Bodyweight is entered in the selected unit but stored as canonical pounds.
            let parsed = parsedValue(for: spec)
            let value = spec.isWeight ? parsed.map(weightUnit.toPounds) : parsed
            spec.assign(measurement, value)
        }
        guard !measurement.isEmpty else { return }
        modelContext.insert(measurement)
        dismiss()
    }
}

/// Describes one editable field: its label, unit suffix, and how to write the
/// parsed value back onto a ``BodyMeasurement``. Declaring the fields once keeps
/// the form, save logic, and validation in lock-step.
struct MeasurementFieldSpec: Identifiable {
    let label: String
    let unit: String?
    /// Whether this field holds a bodyweight — the one field whose unit follows
    /// the weight-unit preference and whose value converts to pounds on save.
    var isWeight = false
    let assign: (BodyMeasurement, Double?) -> Void

    var id: String { label }
    var placeholder: String { unit == "%" ? "0.0" : "—" }

    static let weight = MeasurementFieldSpec(label: "Weight", unit: nil, isWeight: true) { $0.weight = $1 }
    static let bodyFat = MeasurementFieldSpec(label: "Body Fat", unit: "%") { $0.bodyFatPercentage = $1 }

    static let circumferences: [MeasurementFieldSpec] = [
        MeasurementFieldSpec(label: "Neck", unit: nil) { $0.neck = $1 },
        MeasurementFieldSpec(label: "Shoulders", unit: nil) { $0.shoulders = $1 },
        MeasurementFieldSpec(label: "Chest", unit: nil) { $0.chest = $1 },
        MeasurementFieldSpec(label: "Waist", unit: nil) { $0.waist = $1 },
        MeasurementFieldSpec(label: "Hips", unit: nil) { $0.hips = $1 },
        MeasurementFieldSpec(label: "Left Arm", unit: nil) { $0.leftArm = $1 },
        MeasurementFieldSpec(label: "Right Arm", unit: nil) { $0.rightArm = $1 },
        MeasurementFieldSpec(label: "Left Thigh", unit: nil) { $0.leftThigh = $1 },
        MeasurementFieldSpec(label: "Right Thigh", unit: nil) { $0.rightThigh = $1 },
        MeasurementFieldSpec(label: "Left Calf", unit: nil) { $0.leftCalf = $1 },
        MeasurementFieldSpec(label: "Right Calf", unit: nil) { $0.rightCalf = $1 },
    ]

    static let all: [MeasurementFieldSpec] = [weight, bodyFat] + circumferences
}

#Preview {
    NavigationStack {
        AddMeasurementView()
    }
    .modelContainer(Persistence.inMemoryContainer())
}
