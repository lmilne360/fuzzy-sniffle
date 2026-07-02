import SwiftData
import SwiftUI

// MARK: - Derived metrics

extension Workout {
    /// Elapsed wall-clock time of the session, when both bounds are known.
    /// Falls back to `nil` for sessions missing a start or finish stamp.
    var duration: TimeInterval? {
        guard let startedAt, let finishedAt else { return nil }
        return max(0, finishedAt.timeIntervalSince(startedAt))
    }

    /// Total working volume: Σ (reps × weight) across every non-warm-up set.
    /// Warm-ups are excluded to mirror the working-set totals used elsewhere
    /// (see ``SetEntry/isWarmup``). Weight is unitless here; unit handling is a
    /// UI/settings concern the data model deliberately stays out of.
    var totalVolume: Double {
        exercises.reduce(0) { runningTotal, exercise in
            runningTotal + exercise.sets.reduce(0) { setTotal, set in
                setTotal + (set.isWarmup ? 0 : Double(set.reps) * set.weight)
            }
        }
    }

    /// Count of logged sets excluding warm-ups.
    var workingSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.lazy.filter { !$0.isWarmup }.count }
    }

    /// A friendly, derived title for the session.
    ///
    /// The data model has no explicit workout name, so history labels each
    /// session by the daypart it started in ("Morning Workout", etc.). The hour
    /// comes from `startedAt` when available, otherwise the `date`.
    var displayName: String {
        let reference = startedAt ?? date
        let hour = Calendar.current.component(.hour, from: reference)
        switch hour {
        case 5..<12: return "Morning Workout"
        case 12..<17: return "Afternoon Workout"
        case 17..<21: return "Evening Workout"
        default: return "Night Workout"
        }
    }
}

// MARK: - Shared formatting

/// Formatting helpers shared by the history list and detail view so a workout's
/// duration renders identically everywhere. Weight and volume values are
/// unit-aware and formatted through ``WeightFormat`` instead.
enum WorkoutFormat {
    /// A compact duration such as `52 min` or `1h 05m`. Returns `nil` when the
    /// session has no measurable duration.
    static func duration(_ interval: TimeInterval?) -> String? {
        guard let interval else { return nil }
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return "\(minutes) min"
    }
}

// MARK: - Detail

/// The rich detail view for a single logged workout.
///
/// Shows a summary header (duration, total volume, exercise and set counts)
/// followed by every exercise and its logged sets — reps × weight, warm-up and
/// completion state, plus any per-exercise notes. Read-only: history is a record
/// of what happened, editing lives in ``ActiveWorkoutView``.
struct WorkoutDetailView: View {
    let workout: Workout

    /// The unit the volume total is shown in; storage stays pounds.
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback

    var body: some View {
        List {
            Section {
                summaryHeader
            }

            ForEach(workout.orderedExercises) { workoutExercise in
                ExerciseDetailSection(workoutExercise: workoutExercise)
            }
        }
        .navigationTitle(workout.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(workout.date, format: .dateTime.weekday(.wide).month().day().year())
                .font(.headline)

            HStack(alignment: .top, spacing: 24) {
                if let duration = WorkoutFormat.duration(workout.duration) {
                    metric("Duration", duration)
                }
                metric("Volume", WeightFormat.volume(workout.totalVolume, in: weightUnit))
                metric("Exercises", "\(workout.exercises.count)")
                metric("Sets", "\(workout.workingSetCount)")
            }
        }
        .padding(.vertical, 4)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Exercise section

/// One exercise within the detail view: its name, optional notes, and the list
/// of logged sets.
private struct ExerciseDetailSection: View {
    let workoutExercise: WorkoutExercise

    var body: some View {
        Section {
            if !workoutExercise.notes.isEmpty {
                Text(workoutExercise.notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(workoutExercise.orderedSets) { set in
                SetDetailRow(set: set)
            }
        } header: {
            Text(workoutExercise.exercise?.name ?? "Exercise")
        }
    }
}

/// A single logged set: its number (or warm-up marker), reps × weight, and a
/// completion checkmark.
private struct SetDetailRow: View {
    let set: SetEntry

    /// The unit the set's weight is shown in; storage stays pounds.
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback

    var body: some View {
        HStack(spacing: 12) {
            Text(set.isWarmup ? "W" : "\(set.order + 1)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(width: 26, height: 26)
                .background(
                    set.isWarmup ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.15),
                    in: Circle()
                )
                .foregroundStyle(set.isWarmup ? Color.orange : .secondary)
                .accessibilityLabel(set.isWarmup ? "Warm-up set" : "Set \(set.order + 1)")

            Text("\(set.reps) reps × \(WeightFormat.weight(set.weight, in: weightUnit))")
                .font(.body.monospacedDigit())

            Spacer()

            if set.completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                    .accessibilityLabel("Completed")
            }
        }
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    let context = container.mainContext
    ExerciseLibrary.seedIfNeeded(in: context)

    let workout = Workout(
        date: .now,
        startedAt: .now.addingTimeInterval(-3720),
        finishedAt: .now
    )
    context.insert(workout)
    if let exercise = try? context.fetch(FetchDescriptor<Exercise>()).first {
        let we = WorkoutExercise(order: 0, exercise: exercise)
        we.notes = "Felt strong today."
        we.workout = workout
        we.sets = [
            SetEntry(order: 0, reps: 10, weight: 45, completed: true, isWarmup: true),
            SetEntry(order: 1, reps: 8, weight: 135, completed: true),
            SetEntry(order: 2, reps: 8, weight: 135, completed: true),
        ]
        for set in we.sets { set.workoutExercise = we }
        workout.exercises = [we]
    }

    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
}
