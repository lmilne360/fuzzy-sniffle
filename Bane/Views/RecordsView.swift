import SwiftData
import SwiftUI

/// The Records tab: every exercise that has earned a personal record, with its
/// best estimated 1RM as a headline and a tap-through to the full breakdown.
///
/// Reads the persisted ``PersonalRecord`` cache via `@Query` and refreshes it on
/// appear through ``PersonalRecordsService`` so records stay current as new
/// workouts are logged. Read-only.
struct RecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [PersonalRecord]

    var body: some View {
        List {
            ForEach(groupedExercises) { group in
                NavigationLink {
                    ExerciseDetailView(exercise: group.exercise)
                } label: {
                    ExerciseRecordRow(group: group)
                }
            }
        }
        .navigationTitle("Records")
        .overlay {
            if groupedExercises.isEmpty {
                emptyState
            }
        }
        .task { PersonalRecordsService.refresh(in: modelContext) }
    }

    /// Records grouped by exercise, one entry per exercise, sorted by name.
    /// Records with a nil exercise (orphaned by a deletion) are skipped.
    private var groupedExercises: [ExerciseRecordGroup] {
        let byExercise = Dictionary(grouping: records) { $0.exercise?.id }
        return byExercise.compactMap { _, records -> ExerciseRecordGroup? in
            guard let exercise = records.first?.exercise else { return nil }
            return ExerciseRecordGroup(exercise: exercise, records: records)
        }
        .sorted { $0.exercise.name.localizedCaseInsensitiveCompare($1.exercise.name) == .orderedAscending }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Records Yet", systemImage: "trophy")
        } description: {
            Text("Finish a workout to start setting personal records.")
        }
    }
}

/// One exercise's set of personal records, grouped for the overview list.
private struct ExerciseRecordGroup: Identifiable {
    let exercise: Exercise
    let records: [PersonalRecord]

    var id: UUID { exercise.id }

    /// The best estimated 1RM, shown as the row's headline metric.
    var estimatedOneRepMax: PersonalRecord? {
        records.first { $0.metric == .estimatedOneRepMax }
    }
}

/// A row in the Records overview: exercise name, record count, and its
/// estimated 1RM as the trailing headline.
private struct ExerciseRecordRow: View {
    let group: ExerciseRecordGroup

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.exercise.name)
                    .font(.body.weight(.medium))
                Text("\(group.records.count) record\(group.records.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let oneRepMax = group.estimatedOneRepMax {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(WorkoutFormat.volume(oneRepMax.value))
                        .font(.headline.monospacedDigit())
                    Text("est. 1RM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    let context = container.mainContext
    ExerciseLibrary.seedIfNeeded(in: context)

    let exercises = Array(try! context.fetch(FetchDescriptor<Exercise>()).prefix(3))
    let workout = Workout(date: .now, startedAt: .now.addingTimeInterval(-3600), finishedAt: .now)
    context.insert(workout)
    for (index, exercise) in exercises.enumerated() {
        let we = WorkoutExercise(order: index, exercise: exercise)
        we.workout = workout
        we.sets = [SetEntry(order: 0, reps: 5, weight: 135 + Double(index * 20), completed: true)]
        for set in we.sets { set.workoutExercise = we }
        workout.exercises.append(we)
    }

    return NavigationStack {
        RecordsView()
    }
    .modelContainer(container)
}
