import SwiftData
import SwiftUI

/// Rate of Perceived Exertion choices offered per set, on the standard 6–10
/// half-point scale used by strength trainers.
enum RPEScale {
    /// Selectable values, ascending.
    static let values: [Double] = [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10]

    /// A compact label dropping the trailing `.0` on whole numbers (`8`, `8.5`).
    static func label(_ value: Double) -> String {
        value.rounded() == value
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

/// Insertion of a single manually-added warm-up set into an exercise.
///
/// Extracted from the view so the ordering contract — warm-ups lead, the new
/// row tails the existing warm-up block, working sets renumber to follow — is
/// unit-testable against SwiftData models.
enum ManualWarmup {
    /// Appends a blank warm-up set to `workoutExercise`, ordered at the tail of
    /// the warm-up block (ahead of the working sets), and renumbers the working
    /// sets to follow. Returns the newly inserted set.
    @discardableResult
    static func insert(into workoutExercise: WorkoutExercise) -> SetEntry {
        let warmups = workoutExercise.orderedSets.filter(\.isWarmup)
        let workingSets = workoutExercise.orderedSets.filter { !$0.isWarmup }

        let newWarmup = SetEntry(order: warmups.count, isWarmup: true)
        newWarmup.workoutExercise = workoutExercise
        workoutExercise.sets.append(newWarmup)

        // Warm-ups lead; working sets follow the (now larger) warm-up block.
        for (offset, set) in workingSets.enumerated() {
            set.order = warmups.count + 1 + offset
        }
        return newWarmup
    }
}

/// Look-up of what the user did *last time* for an exercise, surfaced as ghost
/// values beside each set while logging (Strong's signature "previous" column).
///
/// Extracted from the view so the two rules — which past session counts, and how
/// its sets line up with the current ones — are unit-testable against SwiftData
/// models. Purely read-only: it traverses existing relationships and never
/// mutates or fetches (ba-oy0.1).
enum PreviousSession {
    /// A single set's performed values from a previous session, in canonical
    /// pounds (the UI converts to the user's unit at the display boundary).
    struct SetValue: Equatable {
        let reps: Int
        /// Weight in canonical pounds — see ``WeightUnit``.
        let weight: Double
    }

    /// The working sets `exercise` was last trained with, drawn from its most
    /// recent *finished* workout other than `current`. Warm-ups are excluded and
    /// the sets come back in performed order; empty when the exercise has no
    /// prior finished session.
    static func lastWorkingSets(
        for exercise: Exercise,
        excluding current: WorkoutExercise
    ) -> [SetEntry] {
        let mostRecent = exercise.workoutExercises
            .filter { $0.id != current.id }
            .compactMap { entry -> (Date, WorkoutExercise)? in
                guard let finishedAt = entry.workout?.finishedAt else { return nil }
                return (finishedAt, entry)
            }
            .max { $0.0 < $1.0 }?
            .1
        return mostRecent?.orderedSets.filter { !$0.isWarmup } ?? []
    }

    /// Maps each current *working* set to the value performed in the same
    /// position last session, keyed by set id for the row to look up. Sets beyond
    /// last session's count — and warm-up rows — are absent, so no ghost shows.
    static func lastValues(for workoutExercise: WorkoutExercise) -> [UUID: SetValue] {
        guard let exercise = workoutExercise.exercise else { return [:] }
        let previous = lastWorkingSets(for: exercise, excluding: workoutExercise)
        guard !previous.isEmpty else { return [:] }

        var values: [UUID: SetValue] = [:]
        var index = 0
        for set in workoutExercise.orderedSets where !set.isWarmup {
            guard index < previous.count else { break }
            values[set.id] = SetValue(reps: previous[index].reps, weight: previous[index].weight)
            index += 1
        }
        return values
    }
}

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
    @AppStorage(RestPreferences.warmupSecondsKey)
    private var warmupRestSeconds = RestPreferences.fallbackWarmupSeconds
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
                            superset: superset(for: workoutExercise),
                            onAddSet: { addSet(to: workoutExercise) },
                            onAddWarmupSet: { addWarmupSet(to: workoutExercise) },
                            onDeleteSets: { offsets in
                                deleteSets(at: offsets, from: workoutExercise)
                            },
                            onRemoveExercise: { remove(workoutExercise) },
                            onComplete: { set in startRest(for: workoutExercise, set: set) },
                            onAddWarmups: { warmups in
                                addWarmupSets(warmups, to: workoutExercise)
                            },
                            onSupersetWithNext: hasNextExercise(after: workoutExercise)
                                ? { supersetWithNext(workoutExercise) }
                                : nil,
                            onLeaveSuperset: workoutExercise.isInSuperset
                                ? { leaveSuperset(workoutExercise) }
                                : nil
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

    /// Auto-starts the rest countdown when a set is checked complete. A
    /// per-exercise override wins; otherwise warm-up sets use the warm-up default
    /// and working sets the working default. A no-op when auto-start is disabled.
    private func startRest(for workoutExercise: WorkoutExercise, set: SetEntry) {
        guard autoStartRest else { return }
        let seconds = RestPreferences.restDuration(
            isWarmup: set.isWarmup,
            exerciseOverride: workoutExercise.exercise?.restDuration,
            workingDefault: defaultRestSeconds,
            warmupDefault: warmupRestSeconds
        )
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

    /// Replaces the exercise's warm-up sets with a freshly calculated ladder,
    /// prepending them ahead of the working sets and renumbering so warm-ups lead.
    ///
    /// Existing warm-ups are cleared first so re-running the calculator swaps in a
    /// new ramp rather than stacking duplicates; the working sets keep their
    /// order. Marked `isWarmup`, the new rows are ordinary sets the user can edit
    /// or delete like any other.
    private func addWarmupSets(
        _ warmups: [WarmupCalculator.WarmupSet],
        to workoutExercise: WorkoutExercise
    ) {
        guard !warmups.isEmpty else { return }

        let workingSets = workoutExercise.orderedSets.filter { !$0.isWarmup }
        for stale in workoutExercise.sets where stale.isWarmup {
            modelContext.delete(stale)
        }

        let newWarmups = warmups.enumerated().map { index, warmup in
            let set = SetEntry(order: index, reps: warmup.reps, weight: warmup.weight, isWarmup: true)
            set.workoutExercise = workoutExercise
            return set
        }
        workoutExercise.sets.append(contentsOf: newWarmups)

        // Warm-ups lead in ladder order, working sets follow in their existing order.
        for (offset, set) in workingSets.enumerated() {
            set.order = newWarmups.count + offset
        }
    }

    /// Inserts a single blank warm-up set ahead of the working sets, renumbering
    /// so warm-ups lead. The new row is an ordinary editable set (reps/weight)
    /// flagged `isWarmup`, tailing any existing warm-ups.
    private func addWarmupSet(to workoutExercise: WorkoutExercise) {
        ManualWarmup.insert(into: workoutExercise)
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
        // Removing a member may leave a superset with a single exercise.
        normalizeSupersets()
    }

    // MARK: - Supersets

    /// Display metadata for the superset `workoutExercise` belongs to, or `nil`
    /// if it stands alone. Letters (A, B, …) are assigned top-to-bottom.
    private func superset(for workoutExercise: WorkoutExercise) -> SupersetContext? {
        guard let group = workoutExercise.supersetGroup,
              let letter = supersetLetters[group] else { return nil }
        for block in workout.exerciseGroups where block.first?.supersetGroup == group {
            guard let position = block.firstIndex(where: { $0.id == workoutExercise.id }) else {
                break
            }
            return SupersetContext(letter: letter, index: position + 1, count: block.count)
        }
        return nil
    }

    /// Stable A, B, C… labels for each active superset, in display order.
    private var supersetLetters: [UUID: String] {
        var letters: [UUID: String] = [:]
        var index = 0
        for block in workout.exerciseGroups where block.count > 1 {
            guard let group = block.first?.supersetGroup else { continue }
            let scalar = UnicodeScalar(65 + min(index, 25))!
            letters[group] = String(scalar)
            index += 1
        }
        return letters
    }

    private func hasNextExercise(after workoutExercise: WorkoutExercise) -> Bool {
        let ordered = workout.orderedExercises
        guard let index = ordered.firstIndex(where: { $0.id == workoutExercise.id }) else {
            return false
        }
        return index + 1 < ordered.count
    }

    /// Links `workoutExercise` with the exercise directly below it into a
    /// superset — extending its existing group, or creating a fresh one.
    private func supersetWithNext(_ workoutExercise: WorkoutExercise) {
        let ordered = workout.orderedExercises
        guard let index = ordered.firstIndex(where: { $0.id == workoutExercise.id }),
              index + 1 < ordered.count else { return }
        let group = workoutExercise.supersetGroup ?? UUID()
        workoutExercise.supersetGroup = group
        ordered[index + 1].supersetGroup = group
        normalizeSupersets()
    }

    /// Detaches `workoutExercise` from its superset, dissolving the group if
    /// only one member would remain.
    private func leaveSuperset(_ workoutExercise: WorkoutExercise) {
        workoutExercise.supersetGroup = nil
        normalizeSupersets()
    }

    /// Enforces the superset invariant: every group must have two or more
    /// *contiguous* members. Any run shorter than two is dissolved back to solo
    /// exercises. Run after any grouping edit.
    private func normalizeSupersets() {
        let ordered = workout.orderedExercises
        var start = 0
        while start < ordered.count {
            guard let group = ordered[start].supersetGroup else {
                start += 1
                continue
            }
            var end = start
            while end < ordered.count && ordered[end].supersetGroup == group {
                end += 1
            }
            if end - start < 2 {
                for i in start..<end { ordered[i].supersetGroup = nil }
            }
            start = end
        }
    }

    /// Completes the session: stamp the finish time so it moves to history, then
    /// mirror it to Apple Health as a strength-training workout (best-effort).
    private func finish() {
        workout.finishedAt = .now
        #if canImport(HealthKit)
        let finished = workout
        Task { await HealthKitService.shared.save(finished) }
        #endif
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

// MARK: - Superset context

/// Display metadata describing where an exercise sits within its superset.
///
/// Built per-render from the workout's grouping so the header can show a stable
/// "Superset A · 1 of 2" chip and decide whether to prompt the user to alternate
/// to the next exercise.
struct SupersetContext {
    /// Group label assigned top-to-bottom (A, B, C…).
    let letter: String
    /// This exercise's 1-based position within the group.
    let index: Int
    /// Total number of exercises in the group.
    let count: Int

    /// `true` when this is the final exercise in the group — after it the user
    /// loops back to the top rather than alternating onward.
    var isLast: Bool { index == count }
}

// MARK: - Exercise section

/// One exercise within the active workout: its header, notes, set list, and an
/// add-set control.
private struct ExerciseSection: View {
    @Bindable var workoutExercise: WorkoutExercise
    /// App-wide default, shown as the fallback choice in the rest override menu.
    let defaultRestSeconds: Int
    /// Superset placement for this exercise, or `nil` when it stands alone.
    let superset: SupersetContext?
    let onAddSet: () -> Void
    /// Inserts a single blank warm-up set ahead of the working sets.
    let onAddWarmupSet: () -> Void
    let onDeleteSets: (IndexSet) -> Void
    let onRemoveExercise: () -> Void
    /// Fired with the set that was just checked complete.
    let onComplete: (SetEntry) -> Void
    /// Prepends a freshly calculated warm-up ladder to this exercise.
    let onAddWarmups: ([WarmupCalculator.WarmupSet]) -> Void
    /// Links this exercise with the one below into a superset. `nil` when there
    /// is no exercise below to link to.
    let onSupersetWithNext: (() -> Void)?
    /// Detaches this exercise from its superset. `nil` when it isn't in one.
    let onLeaveSuperset: (() -> Void)?

    /// Drives the warm-up calculator sheet.
    @State private var isAddingWarmups = false

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
                SetRow(set: set, previous: previousValues[set.id], onComplete: onComplete)
            }
            .onDelete(perform: onDeleteSets)

            Button(action: onAddSet) {
                Label("Add Set", systemImage: "plus")
                    .font(.callout)
            }

            Button(action: onAddWarmupSet) {
                Label("Add Warm-up Set", systemImage: "flame")
                    .font(.callout)
            }
        } header: {
            VStack(alignment: .leading, spacing: 6) {
                if let superset {
                    supersetBadge(superset)
                }
                HStack {
                    Text(workoutExercise.exercise?.name ?? "Exercise")
                    Spacer()
                    warmupButton
                    supersetMenu
                    restMenu
                    Button(role: .destructive, action: onRemoveExercise) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove exercise")
                }
            }
        } footer: {
            if let superset, !superset.isLast {
                Label(
                    "Alternate to the next exercise, then continue.",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .font(.caption)
                .textCase(nil)
            }
        }
        .sheet(isPresented: $isAddingWarmups) {
            WarmupCalculatorView(initialWorkingWeight: warmupSeedWeight, onAdd: onAddWarmups)
        }
    }

    /// A flame button that opens the warm-up calculator for this exercise.
    private var warmupButton: some View {
        Button {
            isAddingWarmups = true
        } label: {
            Image(systemName: "flame")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .textCase(nil)
        .accessibilityLabel("Add warm-up sets")
    }

    /// What the user did last session, keyed by current set id, for the "last
    /// time" ghost values. Recomputed per render — cheap for realistic set counts.
    private var previousValues: [UUID: PreviousSession.SetValue] {
        PreviousSession.lastValues(for: workoutExercise)
    }

    /// Weight the warm-up calculator opens on: the heaviest working set, falling
    /// back to the last logged set, then zero for a fresh exercise.
    private var warmupSeedWeight: Double {
        let working = workoutExercise.orderedSets.filter { !$0.isWarmup }
        return working.map(\.weight).max()
            ?? workoutExercise.orderedSets.last?.weight
            ?? 0
    }

    /// The superset identity chip: its letter and this exercise's position
    /// within the group (e.g. "SUPERSET A · 1 of 2").
    private func supersetBadge(_ superset: SupersetContext) -> some View {
        Label(
            "Superset \(superset.letter) · \(superset.index) of \(superset.count)",
            systemImage: "link"
        )
        .font(.caption2.weight(.bold))
        .textCase(nil)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.indigo.opacity(0.18), in: Capsule())
        .foregroundStyle(Color.indigo)
        .accessibilityLabel(
            "Superset \(superset.letter), exercise \(superset.index) of \(superset.count)"
        )
    }

    /// Grouping controls: link this exercise with the one below, or leave the
    /// current superset. Hidden entirely when neither action is available.
    @ViewBuilder
    private var supersetMenu: some View {
        if onSupersetWithNext != nil || onLeaveSuperset != nil {
            Menu {
                if let onSupersetWithNext {
                    Button {
                        onSupersetWithNext()
                    } label: {
                        Label("Superset with Next", systemImage: "link")
                    }
                }
                if let onLeaveSuperset {
                    Button(role: .destructive) {
                        onLeaveSuperset()
                    } label: {
                        Label("Remove from Superset", systemImage: "minus.circle")
                    }
                }
            } label: {
                Image(systemName: "link")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .textCase(nil)
            .accessibilityLabel("Superset options")
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
    /// What was performed for this set last session, or `nil` when there's no
    /// prior session to show. Drives the "last time" ghost line.
    let previous: PreviousSession.SetValue?
    /// Called with this set when it transitions into the completed state.
    let onComplete: (SetEntry) -> Void

    /// The unit weights are displayed and entered in; storage stays pounds.
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback

    /// Drives the per-set plate-calculator sheet.
    @State private var isShowingPlateCalculator = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            fields
            if let previous {
                previousLabel(previous)
            }
        }
    }

    /// The editable set controls: warm-up flag, reps × weight, RPE, plates, done.
    private var fields: some View {
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

            fieldColumn(title: "Weight (\(weightUnit.abbreviation))") {
                TextField("0", value: $set.weight.weightDisplay(in: weightUnit), format: .number)
                    .keyboardType(.decimalPad)
            }

            rpeColumn

            Button {
                isShowingPlateCalculator = true
            } label: {
                Image(systemName: "circle.grid.2x1.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Plate calculator")
            .accessibilityHint("Breaks this weight into plates per side")

            Button {
                set.completed.toggle()
                if set.completed { onComplete(set) }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.completed ? Color.green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.completed ? "Completed" : "Not completed")
        }
        .sheet(isPresented: $isShowingPlateCalculator) {
            PlateCalculatorView(initialTarget: set.weight)
        }
    }

    /// The "last time" ghost line: what the user performed for this set in their
    /// most recent session, as reps × weight in the current unit. Low-emphasis and
    /// inset past the set-number circle so it reads as a hint beneath the fields.
    private func previousLabel(_ previous: PreviousSession.SetValue) -> some View {
        let weight = WeightFormat.weight(previous.weight, in: weightUnit)
        return Text("Last time: \(previous.reps) × \(weight)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.leading, 38)
            .accessibilityLabel("Last time \(previous.reps) reps at \(weight)")
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

    /// Optional RPE picker, matching the titled column layout of reps/weight.
    /// Bounded to the 6–10 half-point scale, with a dash for "not recorded".
    private var rpeColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("RPE")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Menu {
                Picker("RPE", selection: $set.rpe) {
                    Text("—").tag(Double?.none)
                    ForEach(RPEScale.values, id: \.self) { value in
                        Text(RPEScale.label(value)).tag(Double?.some(value))
                    }
                }
            } label: {
                Text(set.rpe.map(RPEScale.label) ?? "—")
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("RPE")
        .accessibilityValue(set.rpe.map(RPEScale.label) ?? "Not set")
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
            SetEntry(order: 1, reps: 8, weight: 135, completed: true, rpe: 8),
            SetEntry(order: 2, reps: 8, weight: 135),
        ]
        for set in we.sets { set.workoutExercise = we }
        workout.exercises = [we]
    }

    return ActiveWorkoutView(workout: workout)
        .modelContainer(container)
}
