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
    @Environment(\.banePalette) private var palette
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    /// The workout currently presented full-screen for logging.
    @State private var activeWorkout: Workout?

    /// Whether the rest-timer preferences sheet is showing.
    @State private var isShowingRestSettings = false

    /// Whether the CSV data-export sheet is showing.
    @State private var isShowingExport = false

    /// Whether the iCloud-sync preferences sheet is showing.
    @State private var isShowingSyncSettings = false

    var body: some View {
        List {
            if !inProgress.isEmpty {
                Section {
                    ForEach(inProgress) { workout in
                        Button {
                            activeWorkout = workout
                        } label: {
                            WorkoutRow(workout: workout)
                        }
                        .listRowBackground(palette.surface)
                    }
                } header: {
                    Text("In Progress").baneLabel().foregroundStyle(palette.text3)
                }
            }

            if !finished.isEmpty {
                Section {
                    ForEach(finished) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            WorkoutRow(workout: workout)
                        }
                        .listRowBackground(palette.surface)
                    }
                } header: {
                    Text("History").baneLabel().foregroundStyle(palette.text3)
                }
            }
        }
        .listRowSeparatorTint(palette.line)
        .scrollContentBackground(.hidden)
        .background(palette.bg)
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
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingRestSettings = true
                } label: {
                    Label("Rest Timer", systemImage: "timer")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingExport = true
                } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingSyncSettings = true
                } label: {
                    Label("iCloud Sync", systemImage: "icloud")
                }
            }
        }
        .fullScreenCover(item: $activeWorkout) { workout in
            ActiveWorkoutView(workout: workout)
        }
        .sheet(isPresented: $isShowingRestSettings) {
            RestSettingsView()
        }
        .sheet(isPresented: $isShowingExport) {
            DataExportView()
        }
        .sheet(isPresented: $isShowingSyncSettings) {
            SyncSettingsView()
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
            Button("Start Workout", action: startWorkout)
                .buttonStyle(.bane(.primary))
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

    /// The unit volume totals are shown in; storage stays pounds.
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback
    @Environment(\.banePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.displayName)
                    .font(BaneFont.heading(16))
                    .foregroundStyle(palette.text)
                Spacer()
                if !workout.isFinished {
                    BaneBadge(text: "In Progress", kind: .accent)
                }
            }
            Text(workout.date, format: .dateTime.weekday().month().day())
                .font(BaneFont.mono(12))
                .foregroundStyle(palette.text2)
            Text(summary)
                .font(BaneFont.mono(11))
                .foregroundStyle(palette.text3)
        }
        .padding(.vertical, 2)
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
        parts.append("\(WeightFormat.volume(workout.totalVolume, in: weightUnit)) vol")
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
