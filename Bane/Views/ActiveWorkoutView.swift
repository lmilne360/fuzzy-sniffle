import SwiftData
import SwiftUI

/// The active workout-logging surface: the core loop of the app.
///
/// Drives a single in-progress `Workout` — add exercises from the library, log
/// each set as reps × weight, tap sets complete, add/remove sets, flag warm-ups,
/// and record per-exercise notes while a running timer ticks in the toolbar.
/// **Finish** stamps `finishedAt` and persists the session to history;
/// **Discard** deletes the workout entirely.
struct ActiveWorkoutView: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isPickingExercise = false
    @State private var isConfirmingDiscard = false

    /// Drives the between-sets rest countdown surfaced at the bottom of the view.
    @State private var restTimer = RestTimerController()

    @AppStorage(RestPreferences.defaultSecondsKey)
    private var defaultRestSeconds = RestPreferences.fallbackSeconds
    @AppStorage(RestPreferences.autoStartKey)
    private var autoStartRest = true

    var body: some View {
        NavigationStack {
            List {
                if workout.exercises.isEmpty {
                    emptyState
                } else {
                    ForEach(workout.orderedExercises) { workoutExercise in
                        ExerciseSection(
                            workoutExercise: workoutExercise,
                            defaultRestSeconds: defaultRestSeconds,
                            onAddSet: { addSet(to: workoutExercise) },
                            onDeleteSets: { offsets in
                                deleteSets(at: offsets, from: workoutExercise)
                            },
                            onRemoveExercise: { remove(workoutExercise) },
                            onComplete: { startRest(for: workoutExercise) }
                        )
                    }
                }

                Section {
                    Button {
                        isPickingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Discard", role: .destructive) {
                        isConfirmingDiscard = true
                    }
                }
                ToolbarItem(placement: .principal) {
                    WorkoutTimer(startedAt: workout.startedAt ?? workout.date)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish", action: finish)
                        .fontWeight(.semibold)
                        .disabled(workout.exercises.isEmpty)
                }
            }
            .sheet(isPresented: $isPickingExercise) {
                NavigationStack {
                    ExercisePickerView(onSelect: add(_:))
                }
            }
            .confirmationDialog(
                "Discard this workout?",
                isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button("Discard Workout", role: .destructive, action: discard)
                Button("Keep Logging", role: .cancel) {}
            } message: {
                Text("This workout and all its logged sets will be deleted.")
            }
            .safeAreaInset(edge: .bottom) {
                if restTimer.isRunning {
                    RestTimerBar(controller: restTimer)
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .interactiveDismissDisabled()
        .animation(.snappy, value: restTimer.isRunning)
        .task { RestNotifications.requestAuthorization() }
        .onDisappear { restTimer.stop() }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Exercises",
            systemImage: "dumbbell",
            description: Text("Tap Add Exercise to start logging sets.")
        )
    }

    // MARK: - Rest timer

    /// Auto-starts the rest countdown when a set is checked complete, using the
    /// exercise's own override or falling back to the app-wide default. A no-op
    /// when auto-start is disabled in preferences.
    private func startRest(for workoutExercise: WorkoutExercise) {
        guard autoStartRest else { return }
        let seconds = workoutExercise.exercise?.restDuration ?? defaultRestSeconds
        restTimer.start(seconds: seconds, exerciseName: workoutExercise.exercise?.name)
    }

    // MARK: - Mutations

    /// Appends the chosen exercise to the workout, seeding it with one empty set
    /// so the user can start logging immediately.
    private func add(_ exercise: Exercise) {
        let workoutExercise = WorkoutExercise(
            order: workout.exercises.count,
            exercise: exercise
        )
        workoutExercise.workout = workout
        workout.exercises.append(workoutExercise)

        let firstSet = SetEntry(order: 0)
        firstSet.workoutExercise = workoutExercise
        workoutExercise.sets.append(firstSet)
    }

    /// Adds a new set to the exercise, copying the reps/weight of the last set as
    /// a sensible starting point.
    private func addSet(to workoutExercise: WorkoutExercise) {
        let previous = workoutExercise.orderedSets.last
        let newSet = SetEntry(
            order: workoutExercise.sets.count,
            reps: previous?.reps ?? 0,
            weight: previous?.weight ?? 0
        )
        newSet.workoutExercise = workoutExercise
        workoutExercise.sets.append(newSet)
    }

    private func deleteSets(at offsets: IndexSet, from workoutExercise: WorkoutExercise) {
        let ordered = workoutExercise.orderedSets
        for index in offsets {
            modelContext.delete(ordered[index])
        }
        // Compact remaining orders so future inserts stay contiguous.
        for (index, set) in workoutExercise.orderedSets.enumerated() where set.order != index {
            set.order = index
        }
    }

    private func remove(_ workoutExercise: WorkoutExercise) {
        modelContext.delete(workoutExercise)
        for (index, remaining) in workout.orderedExercises.enumerated() where remaining.order != index {
            remaining.order = index
        }
    }

    /// Completes the session: stamp the finish time so it moves to history.
    private func finish() {
        workout.finishedAt = .now
        dismiss()
    }

    /// Abandons the session, deleting the workout and its cascade of children.
    private func discard() {
        modelContext.delete(workout)
        dismiss()
    }
}

// MARK: - Timer

/// A monospaced, self-ticking elapsed-time readout for the running workout.
private struct WorkoutTimer: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            Label(
                Self.elapsed(from: startedAt, to: context.date),
                systemImage: "stopwatch"
            )
            .font(.body.monospacedDigit())
            .labelStyle(.titleAndIcon)
        }
    }

    /// Formats the interval as `M:SS` (or `H:MM:SS` past an hour).
    static func elapsed(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Exercise section

/// One exercise within the active workout: its header, notes, set list, and an
/// add-set control.
private struct ExerciseSection: View {
    @Bindable var workoutExercise: WorkoutExercise
    /// App-wide default, shown as the fallback choice in the rest override menu.
    let defaultRestSeconds: Int
    let onAddSet: () -> Void
    let onDeleteSets: (IndexSet) -> Void
    let onRemoveExercise: () -> Void
    /// Fired when a set within this exercise is checked complete.
    let onComplete: () -> Void

    var body: some View {
        Section {
            TextField(
                "Notes",
                text: $workoutExercise.notes,
                axis: .vertical
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            ForEach(workoutExercise.orderedSets) { set in
                SetRow(set: set, onComplete: onComplete)
            }
            .onDelete(perform: onDeleteSets)

            Button(action: onAddSet) {
                Label("Add Set", systemImage: "plus")
                    .font(.callout)
            }
        } header: {
            HStack {
                Text(workoutExercise.exercise?.name ?? "Exercise")
                Spacer()
                restMenu
                Button(role: .destructive, action: onRemoveExercise) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove exercise")
            }
        }
    }

    /// Per-exercise rest override: pick a preset, or fall back to the app-wide
    /// default. Writes straight through to the referenced `Exercise`.
    @ViewBuilder
    private var restMenu: some View {
        if let exercise = workoutExercise.exercise {
            Menu {
                Picker("Rest", selection: restBinding(for: exercise)) {
                    Text("Default (\(RestDurations.label(defaultRestSeconds)))")
                        .tag(Int?.none)
                    ForEach(RestDurations.presets, id: \.self) { seconds in
                        Text(RestDurations.label(seconds)).tag(Int?.some(seconds))
                    }
                }
            } label: {
                Label(restLabel(for: exercise), systemImage: "timer")
                    .font(.caption)
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
            .textCase(nil)
            .accessibilityLabel("Rest duration for this exercise")
        }
    }

    /// A binding to the exercise's optional rest override for the picker.
    private func restBinding(for exercise: Exercise) -> Binding<Int?> {
        Binding(
            get: { exercise.restDuration },
            set: { exercise.restDuration = $0 }
        )
    }

    /// The header's rest chip: the override if set, otherwise the default.
    private func restLabel(for exercise: Exercise) -> String {
        RestDurations.label(exercise.restDuration ?? defaultRestSeconds)
    }
}

// MARK: - Set row

/// A single editable set: warm-up flag, set number, reps × weight fields, and a
/// tap-to-complete checkmark.
private struct SetRow: View {
    @Bindable var set: SetEntry
    /// Called when this set transitions into the completed state.
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                set.isWarmup.toggle()
            } label: {
                Text(set.isWarmup ? "W" : "\(set.order + 1)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .frame(width: 26, height: 26)
                    .background(
                        set.isWarmup ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.15),
                        in: Circle()
                    )
                    .foregroundStyle(set.isWarmup ? Color.orange : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isWarmup ? "Warm-up set" : "Working set \(set.order + 1)")
            .accessibilityHint("Toggles warm-up")

            fieldColumn(title: "Reps") {
                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
            }

            fieldColumn(title: "Weight") {
                TextField("0", value: $set.weight, format: .number)
                    .keyboardType(.decimalPad)
            }

            Button {
                set.completed.toggle()
                if set.completed { onComplete() }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.completed ? Color.green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.completed ? "Completed" : "Not completed")
        }
    }

    /// A titled, right-aligned numeric entry column.
    private func fieldColumn(title: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            field()
                .multilineTextAlignment(.leading)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    let context = container.mainContext
    ExerciseLibrary.seedIfNeeded(in: context)

    let workout = Workout(startedAt: .now)
    context.insert(workout)
    if let bench = try? context.fetch(FetchDescriptor<Exercise>()).first {
        let we = WorkoutExercise(order: 0, exercise: bench)
        we.workout = workout
        we.sets = [
            SetEntry(order: 0, reps: 10, weight: 45, isWarmup: true),
            SetEntry(order: 1, reps: 8, weight: 135, completed: true),
            SetEntry(order: 2, reps: 8, weight: 135),
        ]
        for set in we.sets { set.workoutExercise = we }
        workout.exercises = [we]
    }

    return ActiveWorkoutView(workout: workout)
        .modelContainer(container)
}
