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

    /// The unit the delete-recap volume is shown in; storage stays pounds.
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback

    /// The workout currently presented full-screen for logging.
    @State private var activeWorkout: Workout?

    /// Whether the rest-timer preferences sheet is showing.
    @State private var isShowingRestSettings = false

    /// Whether the CSV data-export sheet is showing.
    @State private var isShowingExport = false

    /// Whether the iCloud-sync preferences sheet is showing.
    @State private var isShowingSyncSettings = false

    /// A completed workout awaiting the delete-confirm dialog's answer.
    @State private var workoutPendingDeleteConfirmation: Workout?

    /// A completed workout whose delete has been confirmed but not yet
    /// committed — hidden from history immediately, but only actually
    /// removed from ``modelContext`` once ``undoTask`` runs out its grace
    /// window without being cancelled by an undo tap.
    @State private var deletedWorkout: Workout?
    @State private var undoSecondsRemaining: Int?
    @State private var undoTask: Task<Void, Never>?

    /// How long an undo toast stays actionable before the delete commits.
    private static let undoWindowSeconds = 5

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
                    .onDelete { offsets in delete(offsets, from: inProgress) }
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                workoutPendingDeleteConfirmation = workout
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("History").baneLabel().foregroundStyle(palette.text3)
                }
            }
        }
        .listRowSeparatorTint(palette.line)
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .navigationTitle("Train")
        .overlay {
            if workouts.isEmpty {
                emptyState
            }
        }
        .overlay {
            if let workout = workoutPendingDeleteConfirmation {
                DeleteWorkoutDialog(
                    workout: deleteSummary(for: workout),
                    onCancel: { workoutPendingDeleteConfirmation = nil },
                    onConfirm: { confirmDelete(workout) }
                )
            }
        }
        .animation(.snappy, value: workoutPendingDeleteConfirmation?.persistentModelID)
        .safeAreaInset(edge: .bottom) {
            if let deletedWorkout {
                UndoToast(
                    message: "\(deletedWorkout.displayName) deleted",
                    seconds: undoSecondsRemaining,
                    onAction: undoDelete
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: deletedWorkout?.persistentModelID)
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

    /// Finished sessions, minus one currently hidden behind a pending delete
    /// (confirmed but still inside its undo window — see ``deletedWorkout``).
    private var finished: [Workout] {
        workouts.filter { $0.isFinished && $0.persistentModelID != deletedWorkout?.persistentModelID }
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

    /// Deletes the swiped workouts (and their cascade of exercises/sets) from
    /// `section` — the exact rows currently on screen, so the offsets line up
    /// even though "In Progress" and "History" are filtered views over the
    /// same query.
    private func delete(_ offsets: IndexSet, from section: [Workout]) {
        for index in offsets {
            modelContext.delete(section[index])
        }
    }

    /// Builds the recap shown in ``DeleteWorkoutDialog`` for a completed workout.
    private func deleteSummary(for workout: Workout) -> DeleteWorkoutSummary {
        DeleteWorkoutSummary(
            name: workout.displayName,
            date: workout.date.formatted(.dateTime.month().day().hour().minute()),
            duration: WorkoutFormat.duration(workout.duration),
            volume: WeightFormat.volume(workout.totalVolume, in: weightUnit),
            sets: workout.workingSetCount
        )
    }

    /// Answers the delete-confirm dialog: hides the workout from history
    /// immediately and starts its undo grace window. Any earlier pending
    /// delete is committed right away rather than left to finish its own
    /// window, since only one undo toast is shown at a time.
    private func confirmDelete(_ workout: Workout) {
        workoutPendingDeleteConfirmation = nil
        commitPendingDeleteIfNeeded()

        deletedWorkout = workout
        undoSecondsRemaining = Self.undoWindowSeconds
        undoTask = Task { @MainActor in
            var remaining = Self.undoWindowSeconds
            while remaining > 0 {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                remaining -= 1
                undoSecondsRemaining = remaining
            }
            modelContext.delete(workout)
            deletedWorkout = nil
            undoSecondsRemaining = nil
            undoTask = nil
        }
    }

    /// Cancels the pending delete's grace window, restoring the workout to
    /// history without ever having removed it from ``modelContext``.
    private func undoDelete() {
        undoTask?.cancel()
        undoTask = nil
        deletedWorkout = nil
        undoSecondsRemaining = nil
    }

    /// Commits any delete still inside its undo window, ahead of schedule.
    private func commitPendingDeleteIfNeeded() {
        guard let deletedWorkout else { return }
        undoTask?.cancel()
        undoTask = nil
        modelContext.delete(deletedWorkout)
        self.deletedWorkout = nil
        undoSecondsRemaining = nil
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
