import SwiftData
import SwiftUI

/// Sheet that exports the user's full workout history and personal records as CSV
/// files and hands them to the system share sheet (ba-07l.10).
///
/// The CSV text is produced by the pure ``CSVExporter``; this view is only
/// responsible for querying the store, writing the two files to a temporary
/// directory, and offering them through a `ShareLink`. Files are (re)written when
/// the sheet appears so the export always reflects current data.
struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var workouts: [Workout]
    @Query private var exercises: [Exercise]

    /// Temp-file URLs backing the share sheet; empty until ``prepareFiles()`` runs.
    @State private var exportURLs: [URL] = []
    /// Set when writing a CSV file fails, surfaced inline instead of the ShareLink.
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Workouts & Sets") {
                    LabeledContent("Workouts", value: "\(workouts.count)")
                    LabeledContent("Logged sets", value: "\(loggedSetCount)")
                }

                Section("Personal Records") {
                    LabeledContent("Exercises", value: "\(exercises.count)")
                }

                Section {
                    if let exportError {
                        Label(exportError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    } else if exportURLs.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Preparing export…")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ShareLink(items: exportURLs) {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                        }
                    }
                } footer: {
                    Text("Exports your complete workout history and personal records as CSV files you can save or share.")
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { prepareFiles() }
        }
    }

    /// Total logged sets across all workouts, shown as a quick sanity figure.
    private var loggedSetCount: Int {
        workouts.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets.count } }
    }

    /// Writes the workouts and records CSVs to temporary files and stores their
    /// URLs. Filenames are stable, so re-appearing overwrites the previous export
    /// rather than accumulating junk in the temp directory.
    private func prepareFiles() {
        let files: [(name: String, contents: String)] = [
            ("bane-workouts.csv", CSVExporter.workoutsCSV(from: workouts)),
            ("bane-records.csv", CSVExporter.recordsCSV(for: exercises, in: workouts)),
        ]

        let directory = FileManager.default.temporaryDirectory
        var urls: [URL] = []
        do {
            for file in files {
                let url = directory.appendingPathComponent(file.name)
                try file.contents.write(to: url, atomically: true, encoding: .utf8)
                urls.append(url)
            }
            exportURLs = urls
            exportError = nil
        } catch {
            exportError = "Couldn't prepare export."
        }
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    ExerciseLibrary.seedIfNeeded(in: container.mainContext)
    return DataExportView()
        .modelContainer(container)
}
