import SwiftData
import SwiftUI

/// Browse the built-in training programs and add one to your routines (ba-oy0.5).
///
/// Reached from the Routines tab. Each program pushes a detail screen that
/// previews its workouts and, on confirmation, instantiates them as `Routine`s
/// via ``ProgramLibrary/instantiate(_:in:)`` — after which they appear in the
/// Routines list like any hand-built template.
struct ProgramsView: View {
    private let programs = ProgramLibrary.catalog

    var body: some View {
        List {
            Section {
                ForEach(programs) { program in
                    NavigationLink {
                        ProgramDetailView(program: program)
                    } label: {
                        ProgramRow(program: program)
                    }
                }
            } footer: {
                Text("Adding a program creates a routine for each of its workouts. Fill in your own weights, then start a workout like any other routine.")
            }
        }
        .navigationTitle("Programs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A single program row: name, one-line tagline, and how many routines it makes.
private struct ProgramRow: View {
    let program: ProgramLibrary.Program

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(program.name)
            Text(program.tagline)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(routineCountText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var routineCountText: String {
        let count = program.routineCount
        return "Creates \(count) routine\(count == 1 ? "" : "s")"
    }
}

/// Program detail: overview, a preview of each workout's exercises, and a button
/// that materializes the program into the user's routines.
private struct ProgramDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let program: ProgramLibrary.Program

    /// Set after a successful add so we can confirm before popping back.
    @State private var addedRoutineCount: Int?

    var body: some View {
        List {
            Section {
                Text(program.overview)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(program.workouts.enumerated()), id: \.offset) { _, workout in
                Section(workout.name) {
                    ForEach(Array(workout.exercises.enumerated()), id: \.offset) { _, plan in
                        HStack {
                            Text(plan.exerciseName)
                            Spacer()
                            Text(setsText(for: plan))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button {
                    add()
                } label: {
                    Label("Add to My Routines", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Added to Routines", isPresented: addedAlertBinding) {
            Button("Done") { dismiss() }
        } message: {
            if let count = addedRoutineCount {
                Text("Created \(count) routine\(count == 1 ? "" : "s"). Find \(count == 1 ? "it" : "them") in your Routines list.")
            }
        }
    }

    /// A "N × R" summary for one planned exercise (e.g. "5 × 5").
    private func setsText(for plan: ProgramLibrary.ExercisePlan) -> String {
        "\(plan.setCount) × \(plan.targetReps)"
    }

    private func add() {
        let created = ProgramLibrary.instantiate(program, in: modelContext)
        addedRoutineCount = created.count
    }

    /// Drives the confirmation alert off whether an add has completed.
    private var addedAlertBinding: Binding<Bool> {
        Binding(
            get: { addedRoutineCount != nil },
            set: { if !$0 { addedRoutineCount = nil } }
        )
    }
}

#Preview {
    NavigationStack {
        ProgramsView()
    }
    .modelContainer(Persistence.inMemoryContainer())
}
