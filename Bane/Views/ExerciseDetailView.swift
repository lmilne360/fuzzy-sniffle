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
    @Environment(\.banePalette) private var palette
    @Query private var allRecords: [PersonalRecord]

    var body: some View {
        List {
            Section {
                metadata
            }
            .listRowBackground(palette.surface)

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
                    .listRowBackground(palette.surface)
                }
            }
        }
        .listRowSeparatorTint(palette.line)
        .scrollContentBackground(.hidden)
        .background(palette.bg)
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
                    .font(BaneFont.heading(19))
                    .foregroundStyle(palette.text)
                if exercise.isCustom {
                    BaneBadge(text: "Custom", kind: .accent)
                }
            }
            Text("\(exercise.category.displayName) · \(exercise.primaryMuscle.displayName) · \(exercise.equipment.displayName)")
                .font(BaneFont.mono(12))
                .foregroundStyle(palette.text3)
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

    /// The unit record weights are shown in; storage stays pounds.
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback
    @Environment(\.banePalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.metric.systemImage)
                .font(.body)
                .frame(width: 28, height: 28)
                .background(palette.accentWash, in: Circle())
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(showsExerciseName ? (record.exercise?.name ?? "Exercise") : record.metric.displayName)
                    .font(BaneFont.heading(15))
                    .foregroundStyle(palette.text)
                Text("\(record.reps) reps × \(WeightFormat.weight(record.weight, in: weightUnit)) · \(record.achievedOn.formatted(.dateTime.month().day().year()))")
                    .font(BaneFont.mono(11))
                    .foregroundStyle(palette.text3)
            }

            Spacer()

            Text(WeightFormat.weight(record.value, in: weightUnit))
                .font(BaneFont.mono(17, weight: .semibold))
                .foregroundStyle(palette.accent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(record.metric.displayName): \(WeightFormat.weight(record.value, in: weightUnit)), "
                + "\(record.reps) reps at \(WeightFormat.weight(record.weight, in: weightUnit))"
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
