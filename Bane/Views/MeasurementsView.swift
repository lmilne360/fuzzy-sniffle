import SwiftData
import SwiftUI

/// The Measurements tab: a reverse-chronological history of body snapshots with
/// a tap-through to each entry's full detail and an add button.
///
/// Reads ``BodyMeasurement`` rows via `@Query`, newest first. Rows summarise the
/// headline metrics (weight, body-fat %); the detail view lists every recorded
/// field. Entries can be swiped away.
struct MeasurementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    @State private var isAddingMeasurement = false

    var body: some View {
        List {
            ForEach(measurements) { measurement in
                NavigationLink {
                    MeasurementDetailView(measurement: measurement)
                } label: {
                    MeasurementRow(measurement: measurement)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Measurements")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingMeasurement = true
                } label: {
                    Label("Add Measurement", systemImage: "plus")
                }
            }
        }
        .overlay {
            if measurements.isEmpty {
                emptyState
            }
        }
        .sheet(isPresented: $isAddingMeasurement) {
            NavigationStack {
                AddMeasurementView()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(measurements[index])
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Measurements Yet", systemImage: "ruler")
        } description: {
            Text("Log your bodyweight, body-fat %, and circumferences to track progress over time.")
        }
    }
}

/// Shared formatting for measurement values so rows and detail render alike.
enum MeasurementFormat {
    /// A trimmed decimal such as `181.5` or `18` (no trailing `.0`).
    static func value(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

/// A history row: the date headline with weight and body-fat % as trailing
/// summary metrics when present.
private struct MeasurementRow: View {
    let measurement: BodyMeasurement

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(measurement.date, format: .dateTime.year().month().day())
                    .font(.body.weight(.medium))
                Text("\(measurement.recordedFields.count) metric\(measurement.recordedFields.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let weight = measurement.weight {
                summaryMetric(MeasurementFormat.value(weight), caption: "weight")
            }
            if let bodyFat = measurement.bodyFatPercentage {
                summaryMetric("\(MeasurementFormat.value(bodyFat))%", caption: "body fat")
            }
        }
    }

    private func summaryMetric(_ value: String, caption: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 12)
    }
}

/// Full breakdown of a single measurement: every recorded field plus any notes.
struct MeasurementDetailView: View {
    let measurement: BodyMeasurement

    var body: some View {
        List {
            Section("Metrics") {
                ForEach(measurement.recordedFields, id: \.label) { field in
                    if let value = field.value {
                        LabeledContent(field.label) {
                            Text(displayValue(field.label, value))
                                .monospacedDigit()
                        }
                    }
                }
            }

            if !measurement.notes.isEmpty {
                Section("Notes") {
                    Text(measurement.notes)
                }
            }
        }
        .navigationTitle(measurement.date.formatted(.dateTime.year().month().day()))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Appends a `%` to the body-fat field; other metrics are unitless.
    private func displayValue(_ label: String, _ value: Double) -> String {
        let formatted = MeasurementFormat.value(value)
        return label == "Body Fat %" ? "\(formatted)%" : formatted
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    let context = container.mainContext
    context.insert(BodyMeasurement(date: .now, weight: 181.4, bodyFatPercentage: 17.2, chest: 42, waist: 33))
    context.insert(BodyMeasurement(date: .now.addingTimeInterval(-7 * 86_400), weight: 183.0, bodyFatPercentage: 18.1))

    return NavigationStack {
        MeasurementsView()
    }
    .modelContainer(container)
}
