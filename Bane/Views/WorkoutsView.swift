import SwiftData
import SwiftUI

/// The Workouts tab: the entry point to the core logging loop and workout history.
///
/// Starts a new empty workout (or resumes an in-progress one) and presents
/// ``ActiveWorkoutView``. Finished sessions are listed as history — each row
/// summarizes the session and taps through to ``WorkoutDetailView`` for a full
/// breakdown of every exercise and logged set.
struct WorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    /// The workout currently presented full-screen for logging.
    @State private var activeWorkout: Workout?

    var body: some View {
        List {
            if !inProgress.isEmpty {
                Section("In Progress") {
                    ForEach(inProgress) { workout in
                        Button {
                            activeWorkout = workout
                        } label: {
                            WorkoutRow(workout: workout)
                        }
                    }
                }
            }

            if !finished.isEmpty {
                Section("History") {
                    ForEach(finished) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            WorkoutRow(workout: workout)
                        }
                    }
                }
            }
        }
        .navigationTitle("Workouts")
        .overlay {
            if workouts.isEmpty {
                emptyState
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: startWorkout) {
                    Label("Start Workout", systemImage: "plus")
                }
            }
        }
        .fullScreenCover(item: $activeWorkout) { workout in
            ActiveWorkoutView(workout: workout)
        }
    }

    private var inProgress: [Workout] {
        workouts.filter { !$0.isFinished }
    }

    private var finished: [Workout] {
        workouts.filter(\.isFinished)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Workouts Yet", systemImage: "dumbbell")
        } description: {
            Text("Start a workout to log your sets, reps, and weight.")
        } actions: {
            Button(action: startWorkout) {
                Text("Start Workout")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// Creates a fresh empty workout and opens it for logging.
    private func startWorkout() {
        let workout = Workout(startedAt: .now)
        modelContext.insert(workout)
        activeWorkout = workout
    }
}

/// A summary row for a workout: name, date, and — for finished sessions —
/// duration, total volume, and exercise count. In-progress sessions show a
/// badge and a lighter set/exercise summary instead.
private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.displayName)
                    .font(.headline)
                Spacer()
                if !workout.isFinished {
                    Text("In Progress")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
            Text(workout.date, format: .dateTime.weekday().month().day())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// A `·`-separated summary. Finished sessions lead with duration and total
    /// volume; in-progress sessions fall back to a raw set count.
    private var summary: String {
        let exerciseCount = workout.exercises.count
        let exercises = "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"

        guard workout.isFinished else {
            let setCount = workout.exercises.reduce(0) { $0 + $1.sets.count }
            let sets = "\(setCount) set\(setCount == 1 ? "" : "s")"
            return "\(exercises) · \(sets)"
        }

        var parts: [String] = []
        if let duration = WorkoutFormat.duration(workout.duration) {
            parts.append(duration)
        }
        parts.append("\(WorkoutFormat.volume(workout.totalVolume)) vol")
        parts.append(exercises)
        return parts.joined(separator: " · ")
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    ExerciseLibrary.seedIfNeeded(in: container.mainContext)
    return NavigationStack {
        WorkoutsView()
    }
    .modelContainer(container)
}
