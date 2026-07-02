import SwiftData
import SwiftUI

/// Detail screen for a single exercise: its classification plus the personal
/// records it has earned across workout history.
///
/// Records are read from the persisted ``PersonalRecord`` cache via `@Query`;
/// the cache is refreshed on appear through ``PersonalRecordsService`` so the
/// numbers reflect the latest finished sessions. This screen is read-only and
/// never mutates workout data.
struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var modelContext
    @Query private var allRecords: [PersonalRecord]

    var body: some View {
        List {
            Section {
                metadata
            }

            Section("Personal Records") {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No Records Yet",
                        systemImage: "trophy",
                        description: Text("Finish a workout with this exercise to set your first record.")
                    )
                } else {
                    ForEach(records) { record in
                        PersonalRecordRow(record: record)
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { PersonalRecordsService.refresh(in: modelContext) }
    }

    /// This exercise's records, ordered by ``PRMetric``'s declared order.
    private var records: [PersonalRecord] {
        let mine = allRecords.filter { $0.exercise?.id == exercise.id }
        return PRMetric.allCases.compactMap { metric in
            mine.first { $0.metric == metric }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.title3.weight(.semibold))
                if exercise.isCustom {
                    Text("Custom")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
            Text("\(exercise.category.displayName) · \(exercise.primaryMuscle.displayName) · \(exercise.equipment.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// A single personal-record row: the metric, its value, and the reps × weight
/// and date that earned it. Shared by ``ExerciseDetailView`` and ``RecordsView``.
struct PersonalRecordRow: View {
    let record: PersonalRecord

    /// Whether to show the exercise name (Records overview) rather than the
    /// metric name (per-exercise detail).
    var showsExerciseName = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.metric.systemImage)
                .font(.body)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: Circle())
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(showsExerciseName ? (record.exercise?.name ?? "Exercise") : record.metric.displayName)
                    .font(.body.weight(.medium))
                Text("\(record.reps) reps × \(WorkoutFormat.volume(record.weight)) · \(record.achievedOn.formatted(.dateTime.month().day().year()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(WorkoutFormat.volume(record.value))
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(record.metric.displayName): \(WorkoutFormat.volume(record.value)), "
                + "\(record.reps) reps at \(WorkoutFormat.volume(record.weight))"
        )
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    let context = container.mainContext
    ExerciseLibrary.seedIfNeeded(in: context)

    let exercise = try! context.fetch(FetchDescriptor<Exercise>()).first!
    let workout = Workout(date: .now, startedAt: .now.addingTimeInterval(-3600), finishedAt: .now)
    context.insert(workout)
    let we = WorkoutExercise(order: 0, exercise: exercise)
    we.workout = workout
    we.sets = [
        SetEntry(order: 0, reps: 5, weight: 185, completed: true),
        SetEntry(order: 1, reps: 3, weight: 205, completed: true),
        SetEntry(order: 2, reps: 8, weight: 155, completed: true),
    ]
    for set in we.sets { set.workoutExercise = we }
    workout.exercises = [we]

    return NavigationStack {
        ExerciseDetailView(exercise: exercise)
    }
    .modelContainer(container)
}
