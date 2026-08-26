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
    ///
    /// `bodyWeight` seeds the set's weight when the exercise is bodyweight (see
    /// ``BodyweightDefault``); pass `nil` when none has been recorded.
    @discardableResult
    static func insert(into workoutExercise: WorkoutExercise, bodyWeight: Double? = nil) -> SetEntry {
        let warmups = workoutExercise.orderedSets.filter(\.isWarmup)
        let workingSets = workoutExercise.orderedSets.filter { !$0.isWarmup }

        let newWarmup = SetEntry(
            order: warmups.count,
            weight: BodyweightDefault.weight(
                for: workoutExercise.exercise, bodyWeight: bodyWeight, fallback: 0
            ),
            isWarmup: true
        )
        newWarmup.workoutExercise = workoutExercise
        workoutExercise.sets.append(newWarmup)

        // Warm-ups lead; working sets follow the (now larger) warm-up block.
        for (offset, set) in workingSets.enumerated() {
            set.order = warmups.count + 1 + offset
        }
        return newWarmup
    }
}

/// Seeding a new set's starting weight for bodyweight exercises.
///
/// Extracted from the view so the rule — a bodyweight exercise's unset weight
/// defaults to the user's most recently recorded body weight rather than
/// zero — is unit-testable without SwiftData.
enum BodyweightDefault {
    /// The weight a freshly created set should start at. Returns `bodyWeight`
    /// when `exercise` trains bodyweight and a body weight has been recorded;
    /// otherwise returns `fallback` unchanged (typically `0`, or a copied-
    /// forward previous weight).
    static func weight(for exercise: Exercise?, bodyWeight: Double?, fallback: Double) -> Double {
        guard exercise?.isBodyweight == true, let bodyWeight else { return fallback }
        return bodyWeight
    }
}

/// Reordering exercises within an active workout via drag-to-reorder.
///
/// Extracted from the view so the contract — `order` renumbers to match the
/// dragged sequence while each exercise's own data (sets, notes, superset
/// membership) travels untouched — is unit-testable against SwiftData models
/// (ba-4j8). Superset membership travels with each exercise as-is; dissolving
/// a group the move splits apart is the caller's responsibility (see
/// `ActiveWorkoutView.normalizeSupersets`).
enum ExerciseReorder {
    /// Moves exercises within `workout` per the standard SwiftUI `onMove`
    /// semantics (source offsets relative to the current order, landing before
    /// `destination`), renumbering `order` to match the new sequence.
    static func move(in workout: Workout, from source: IndexSet, to destination: Int) {
        var ordered = workout.orderedExercises
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in ordered.enumerated() where exercise.order != index {
            exercise.order = index
        }
    }
}

/// Swapping an active-workout exercise for an alternative.
///
/// Extracted from the view so the contract — the referenced exercise changes
/// while the logged set structure (reps, weight, completion, warm-up flags,
/// order) is left untouched — is unit-testable against SwiftData models (ba-oy0.4).
enum ExerciseSwap {
    /// Repoints `workoutExercise` at `replacement`, keeping every logged set as
    /// it was. Only the exercise identity changes, so notes, superset grouping,
    /// and the set ladder all carry over.
    static func swap(_ workoutExercise: WorkoutExercise, to replacement: Exercise) {
        workoutExercise.exercise = replacement
    }
}

/// Identifies which field of which set currently owns the keyboard.
///
/// Hoisted to `ActiveWorkoutView` rather than local to each `SetRow` so that
/// completing a rest can move focus to a different set — possibly in another
/// exercise's row entirely. A per-row `@FocusState` has no way to reach
/// outside its own row; a shared one, passed down as a `FocusState.Binding`,
/// does (ba-84b).
struct SetFieldFocus: Hashable {
    enum Field: Hashable { case reps, weight }
    let setID: UUID
    let field: Field
}

/// The "still working out?" staleness check for the active-workout session
/// clock.
///
/// Extracted from the view so the rule is unit-testable without SwiftUI: a
/// session left running for hours with no pause reads as forgotten, not
/// genuinely ongoing — a paused session's owner has already shown they're
/// tracking it, so it's excluded (ba-84b).
enum StaleWorkoutCheck {
    /// Sessions running longer than this without ever pausing prompt to confirm.
    static let threshold: TimeInterval = 6 * 3600

    /// `true` when `workout` has been running past ``threshold`` and has never
    /// been paused.
    static func isStale(_ workout: Workout, at now: Date) -> Bool {
        guard let startedAt = workout.startedAt else { return false }
        guard workout.pausedAt == nil, workout.pausedTotal == 0 else { return false }
        return now.timeIntervalSince(startedAt) > threshold
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

/// The set to move to once a rest completes or is being previewed: the
/// resting exercise's own next incomplete set, or the next exercise's first
/// set once this one is fully logged.
///
/// Extracted from the view so this traversal — shared by rest-completion
/// focus-advance and the rest sheet's "next up" preview — is unit-testable
/// against SwiftData models and can't drift between the two call sites.
enum NextSet {
    struct Match {
        let workoutExercise: WorkoutExercise
        let set: SetEntry
        /// This set's 1-based position within `workoutExercise`'s sets.
        let position: Int
        /// Total sets in `workoutExercise`, for a "position of total" display.
        let total: Int
    }

    /// The next set to work on after `workoutExercise`, within `workout`'s
    /// exercise order. `nil` when `workoutExercise` is the workout's last
    /// exercise and it's fully logged.
    static func find(after workoutExercise: WorkoutExercise, in workout: Workout) -> Match? {
        let ordered = workoutExercise.orderedSets
        if let index = ordered.firstIndex(where: { !$0.completed }) {
            return Match(workoutExercise: workoutExercise, set: ordered[index], position: index + 1, total: ordered.count)
        }
        let exercises = workout.orderedExercises
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == workoutExercise.id }),
              exerciseIndex + 1 < exercises.count else { return nil }
        let nextExercise = exercises[exerciseIndex + 1]
        guard let firstSet = nextExercise.orderedSets.first else { return nil }
        return Match(workoutExercise: nextExercise, set: firstSet, position: 1, total: nextExercise.orderedSets.count)
    }
}

/// The active workout-logging surface: the core loop of the app.
///
/// Drives a single in-progress `Workout` — add exercises from the library, log
/// each set as reps × weight, tap sets complete, add/remove sets, flag warm-ups,
/// and record per-exercise notes while a running timer ticks in the toolbar.
/// **Finish** stamps `finishedAt` and persists the session to history;
/// **Discard** deletes the workout entirely; the chevron **minimizes** back to
/// the tab bar, leaving the workout running so other pages stay reachable
/// mid-session — it resumes from the Workouts tab's "In Progress" section.
struct ActiveWorkoutView: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.banePalette) private var palette
    @Environment(\.scenePhase) private var scenePhase

    /// Newest first, so ``currentBodyWeight`` is the most recently recorded
    /// value.
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var bodyMeasurements: [BodyMeasurement]

    @State private var isPickingExercise = false
    @State private var isConfirmingDiscard = false
    @State private var isReorderingExercises = false
    /// The exercise the user is choosing a swap replacement for, driving the
    /// alternatives picker sheet. `nil` when no swap is in progress.
    @State private var swappingExercise: WorkoutExercise?

    /// The exercise the user is building a warm-up ladder for, driving the
    /// warm-up calculator sheet. `nil` when no calculator is showing.
    ///
    /// Hoisted here (rather than owned per-row by `ExerciseSection`) because a
    /// `.sheet` bound to `@State` inside a `List` `Section` can present and
    /// immediately dismiss — the section's header/content/footer are
    /// decomposed by the list renderer, so the presenting identity is
    /// unstable. Driving it from a stable ancestor, the same way
    /// `swappingExercise` already does for the swap sheet, avoids that (ba-yy0).
    @State private var warmupTarget: WorkoutExercise?

    /// Drives the between-sets rest countdown surfaced at the bottom of the
    /// view. Looked up from ``RestTimerRegistry`` rather than created fresh so
    /// a running rest survives minimizing and reopening this view.
    @State private var restTimer: RestTimerController

    /// `true` once the rest UI has been minimized to ``RestTimerMinimizedBar``
    /// (scrim tap, grabber tap, or swipe-down on ``RestTimerSheet``); `false`
    /// shows the full sheet. Presentation-layer only — `restTimer` itself is
    /// untouched by this toggle, so a rest keeps counting down either way.
    @State private var isRestSheetMinimized = false

    /// The single tick driving both the session clock and the rest timer's
    /// displayed remaining time — one timer, not two.
    @State private var now = Date()

    /// Which set's reps/weight field currently owns the keyboard, hoisted so
    /// a completed rest can move focus into a different row (see
    /// ``SetFieldFocus``).
    @FocusState private var focusedField: SetFieldFocus?

    /// Guards the "still working out?" prompt so it surfaces at most once per
    /// session rather than every time the app returns to the foreground.
    @State private var hasCheckedStaleness = false
    @State private var isShowingStaleCheck = false

    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    @AppStorage(RestPreferences.defaultSecondsKey)
    private var defaultRestSeconds = RestPreferences.fallbackSeconds
    @AppStorage(RestPreferences.warmupSecondsKey)
    private var warmupRestSeconds = RestPreferences.fallbackWarmupSeconds
    @AppStorage(RestPreferences.autoStartKey)
    private var autoStartRest = true

    init(workout: Workout) {
        self._workout = Bindable(wrappedValue: workout)
        self._restTimer = State(initialValue: RestTimerRegistry.shared.controller(for: workout.id))
    }

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
                            focusedField: $focusedField,
                            onAddSet: { addSet(to: workoutExercise) },
                            onAddWarmupSet: { addWarmupSet(to: workoutExercise) },
                            onDeleteSets: { offsets in
                                deleteSets(at: offsets, from: workoutExercise)
                            },
                            onRemoveExercise: { remove(workoutExercise) },
                            onSwap: { swappingExercise = workoutExercise },
                            onComplete: { set in startRest(for: workoutExercise, set: set) },
                            onUncomplete: { _ in restTimer.stop() },
                            onOpenWarmups: { warmupTarget = workoutExercise },
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
                    .tint(palette.accent)
                    .listRowBackground(palette.surface)
                }
            }
            .listRowSeparatorTint(palette.line)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(palette.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("Minimize workout")
                    .accessibilityHint("Returns to the app while keeping this workout in progress")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    workoutActionMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish", action: finish)
                        .fontWeight(.semibold)
                        .tint(palette.accent)
                        .disabled(workout.exercises.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .sheet(isPresented: $isPickingExercise) {
                NavigationStack {
                    ExercisePickerView(onSelect: add(_:))
                }
            }
            .sheet(item: $swappingExercise) { workoutExercise in
                NavigationStack {
                    ExercisePickerView(
                        alternativesFor: workoutExercise.exercise,
                        title: "Swap Exercise",
                        onSelect: { swap(workoutExercise, to: $0) }
                    )
                }
            }
            .sheet(item: $warmupTarget) { workoutExercise in
                WarmupCalculatorView(
                    initialWorkingWeight: warmupSeedWeight(for: workoutExercise),
                    onAdd: { warmups in addWarmupSets(warmups, to: workoutExercise) }
                )
            }
            .sheet(isPresented: $isReorderingExercises) {
                NavigationStack {
                    ReorderExercisesView(workout: workout, onMove: moveExercises)
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
            .confirmationDialog(
                "Still working out?",
                isPresented: $isShowingStaleCheck,
                titleVisibility: .visible
            ) {
                Button("End Workout", role: .destructive, action: endStaleWorkout)
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("This session has been running for a while. End it at your last logged set, or keep going.")
            }
            .safeAreaInset(edge: .top) {
                WorkoutProgressHeader(workout: workout, now: now, restTimer: restTimer, onTogglePause: togglePause)
            }
            .safeAreaInset(edge: .bottom) {
                if restTimer.isRunning && isRestSheetMinimized {
                    RestTimerMinimizedBar(controller: restTimer, now: now) {
                        isRestSheetMinimized = false
                    }
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .interactiveDismissDisabled()
        .overlay {
            if restTimer.isRunning && !isRestSheetMinimized {
                let preview = restNextSetPreview()
                RestTimerSheet(
                    controller: restTimer,
                    now: now,
                    nextExercise: preview?.workoutExercise.exercise?.name,
                    nextSet: preview?.position,
                    nextSetTotal: preview?.total,
                    onMinimize: { isRestSheetMinimized = true }
                )
                .transition(.opacity)
            }
        }
        .animation(.snappy, value: restTimer.isRunning)
        .animation(.snappy, value: isRestSheetMinimized)
        .task { RestNotifications.requestAuthorization() }
        .onAppear {
            now = Date()
            refreshRestCompletionHandler()
            checkStaleness()
        }
        .onReceive(ticker) { date in
            now = date
            restTimer.tick(date)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            now = Date()
            restTimer.tick(now)
            checkStaleness()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Exercises",
            systemImage: "dumbbell",
            description: Text("Tap Add Exercise to start logging sets.")
        )
    }

    /// The nav row's single overflow menu — consolidates what used to be two
    /// separate icon buttons (Reorder, Discard) crowding the header next to
    /// Finish, mirroring the per-exercise ``ExerciseSection/actionMenu``.
    private var workoutActionMenu: some View {
        Menu {
            if workout.exercises.count > 1 {
                Button {
                    isReorderingExercises = true
                } label: {
                    Label("Reorder Exercises", systemImage: "arrow.up.arrow.down")
                }
            }
            Divider()
            Button(role: .destructive) {
                isConfirmingDiscard = true
            } label: {
                Label("Discard Workout", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Workout actions")
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
        restTimer.start(seconds: seconds, exerciseName: workoutExercise.exercise?.name, exerciseID: workoutExercise.id)
        isRestSheetMinimized = false
        refreshRestCompletionHandler()
    }

    /// The next set to preview on ``RestTimerSheet`` while `restTimer` is
    /// running, derived from the exercise its current rest belongs to. `nil`
    /// once idle or when the rest's exercise was the workout's last one.
    private func restNextSetPreview() -> NextSet.Match? {
        guard let exerciseID = restTimer.exerciseID,
              let workoutExercise = workout.orderedExercises.first(where: { $0.id == exerciseID })
        else { return nil }
        return NextSet.find(after: workoutExercise, in: workout)
    }

    /// (Re)binds `restTimer.onComplete` to *this* view instance.
    ///
    /// `RestTimerController` outlives any single `ActiveWorkoutView` (see
    /// ``RestTimerRegistry``), so a closure captured once at `start(...)` time
    /// would go stale if the view is minimized and a fresh instance takes its
    /// place before the rest completes — writing to that stale instance's
    /// `@FocusState` would silently do nothing. Re-deriving the closure from
    /// `restTimer.exerciseID` against the current `self` whenever this view
    /// (re)appears keeps it valid no matter which instance is showing when the
    /// rest actually completes.
    private func refreshRestCompletionHandler() {
        guard let exerciseID = restTimer.exerciseID else {
            restTimer.onComplete = nil
            return
        }
        restTimer.onComplete = { [weak workout] in
            isRestSheetMinimized = true
            guard let workout,
                  let workoutExercise = workout.orderedExercises.first(where: { $0.id == exerciseID })
            else { return }
            advanceFocus(after: workoutExercise)
        }
    }

    /// Moves keyboard focus to the next incomplete set of `workoutExercise`,
    /// or the next exercise's first set if this one is fully logged. Called
    /// when a rest completes.
    private func advanceFocus(after workoutExercise: WorkoutExercise) {
        guard let next = NextSet.find(after: workoutExercise, in: workout) else { return }
        focusedField = SetFieldFocus(setID: next.set.id, field: .reps)
    }

    // MARK: - Session clock

    /// Toggles the session pause/resume state, freezing (or restoring) both
    /// the session clock and the rest timer at exactly the same instant.
    private func togglePause() {
        let date = Date()
        if workout.isPaused {
            workout.resume(at: date)
            restTimer.resume(at: date)
        } else {
            workout.pause(at: date)
            restTimer.pause(at: date)
        }
        now = date
    }

    /// Surfaces the "still working out?" prompt once per session when the
    /// workout has run past ``StaleWorkoutCheck/threshold`` without a pause.
    private func checkStaleness() {
        guard !hasCheckedStaleness, StaleWorkoutCheck.isStale(workout, at: now) else { return }
        hasCheckedStaleness = true
        isShowingStaleCheck = true
    }

    /// Ends a stale session at its last logged set's timestamp (falling back
    /// to when it started) rather than the moment the user happened to reopen
    /// the app.
    private func endStaleWorkout() {
        complete(at: workout.lastLoggedSetTimestamp ?? workout.startedAt ?? .now)
    }

    // MARK: - Mutations

    /// The user's most recently recorded body weight, or `nil` if none has been
    /// entered. Feeds ``BodyweightDefault`` when seeding new sets.
    private var currentBodyWeight: Double? {
        bodyMeasurements.first(where: { $0.weight != nil })?.weight
    }

    /// Appends the chosen exercise to the workout, seeding it with one empty set
    /// so the user can start logging immediately.
    private func add(_ exercise: Exercise) {
        let workoutExercise = WorkoutExercise(
            order: workout.exercises.count,
            exercise: exercise
        )
        workoutExercise.workout = workout
        workout.exercises.append(workoutExercise)

        let firstSet = SetEntry(
            order: 0,
            weight: BodyweightDefault.weight(for: exercise, bodyWeight: currentBodyWeight, fallback: 0)
        )
        firstSet.workoutExercise = workoutExercise
        workoutExercise.sets.append(firstSet)
    }

    /// Swaps `workoutExercise` for `replacement`, preserving its logged sets.
    /// The user picked an alternative (same primary muscle) from the swap sheet.
    private func swap(_ workoutExercise: WorkoutExercise, to replacement: Exercise) {
        ExerciseSwap.swap(workoutExercise, to: replacement)
    }

    /// Adds a new set to the exercise, copying the reps/weight of the last set as
    /// a sensible starting point.
    private func addSet(to workoutExercise: WorkoutExercise) {
        let previous = workoutExercise.orderedSets.last
        let fallbackWeight = BodyweightDefault.weight(
            for: workoutExercise.exercise, bodyWeight: currentBodyWeight, fallback: 0
        )
        let newSet = SetEntry(
            order: workoutExercise.sets.count,
            reps: previous?.reps ?? 0,
            weight: previous?.weight ?? fallbackWeight
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
        ManualWarmup.insert(into: workoutExercise, bodyWeight: currentBodyWeight)
    }

    /// Weight the warm-up calculator opens on: the heaviest working set, falling
    /// back to the last logged set, then zero for a fresh exercise.
    private func warmupSeedWeight(for workoutExercise: WorkoutExercise) -> Double {
        let working = workoutExercise.orderedSets.filter { !$0.isWarmup }
        return working.map(\.weight).max()
            ?? workoutExercise.orderedSets.last?.weight
            ?? 0
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

    /// Reorders exercises per a drag-to-reorder gesture, then dissolves any
    /// superset the move split apart (mirrors ``remove(_:)``'s invariant upkeep).
    private func moveExercises(from source: IndexSet, to destination: Int) {
        ExerciseReorder.move(in: workout, from: source, to: destination)
        normalizeSupersets()
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

    /// Completes the session at `finishedAt`: stamps the finish time so it
    /// moves to history, mirrors it to Apple Health (best-effort), and drops
    /// its rest-timer controller from the registry now that the session is over.
    private func complete(at finishedAt: Date) {
        workout.finishedAt = finishedAt
        #if canImport(HealthKit)
        let finished = workout
        Task { await HealthKitService.shared.save(finished) }
        #endif
        RestTimerRegistry.shared.remove(workout.id)
        dismiss()
    }

    /// Completes the session now — the ordinary "Finish" action.
    private func finish() {
        complete(at: .now)
    }

    /// Abandons the session, deleting the workout and its cascade of children,
    /// and drops its rest-timer controller from the registry.
    private func discard() {
        RestTimerRegistry.shared.remove(workout.id)
        restTimer.stop()
        modelContext.delete(workout)
        dismiss()
    }
}

// MARK: - Progress header

/// A pinned header showing the running elapsed time, a pause/resume control,
/// a one-line status caption, and a per-exercise-segmented hairline — replaces
/// the old toolbar timer (which had no room to render its label alongside
/// Discard/Reorder/Finish and so silently collapsed to an unlabeled, inert
/// icon) and the separately-labeled exercise progress bar that used to sit
/// beneath it.
///
/// Driven entirely by `now`, supplied by the owning `ActiveWorkoutView`'s
/// single shared tick — this view has no timer of its own, and the displayed
/// value freezes exactly when `workout.isPaused` because ``Workout/elapsed(at:)``
/// stops advancing at `pausedAt` regardless of how far `now` moves on.
private struct WorkoutProgressHeader: View {
    @Bindable var workout: Workout
    let now: Date
    /// Read (not owned) to surface the "Resting …" caption state — the same
    /// controller ``RestTimerBar`` drives from `ActiveWorkoutView`.
    let restTimer: RestTimerController
    let onTogglePause: () -> Void

    @Environment(\.banePalette) private var palette
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Self.format(elapsed))
                    .font(BaneFont.display(28).monospacedDigit())
                    .foregroundStyle(palette.text)
                    .accessibilityLabel(Self.coarseAccessibilityLabel(elapsed))
                Spacer()
                pauseButton
            }
            caption
            hairline
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(palette.surface)
    }

    private var elapsed: TimeInterval { workout.elapsed(at: now) }

    private var pauseButton: some View {
        Button(action: onTogglePause) {
            Image(systemName: workout.isPaused ? "play.fill" : "pause.fill")
                .font(.body)
                .foregroundStyle(palette.text2)
        }
        .accessibilityLabel(workout.isPaused ? "Resume workout" : "Pause workout")
    }

    // MARK: Caption

    /// One line of status — state (workout name / paused / resting) plus
    /// exercise, set, and volume tallies — mirroring the design system's
    /// `bn-wbar__caption` (mono, uppercase, tracked; bold figures a shade
    /// lighter than the rest of the line).
    private var caption: some View {
        var line = stateOrNameText
        if totalExercises > 0 {
            line = line
                + plain(" · Ex ")
                + bold("\(min(currentExerciseIndex + 1, totalExercises))")
                + plain("/\(totalExercises)")
        }
        if totalWorkingSets > 0 {
            line = line
                + plain(" · ")
                + bold("\(completedWorkingSets)")
                + plain("/\(totalWorkingSets) sets")
        }
        if workout.totalVolume > 0 {
            line = line + plain(" · ") + bold(WeightFormat.volume(workout.totalVolume, in: weightUnit))
        }
        return line
            .baneLabel()
            .foregroundStyle(palette.text3)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    /// The caption's leading segment: the workout's derived name normally,
    /// or the paused/resting state when one is active — matching the design
    /// system's mutually-exclusive `state` vs. `name` display.
    private var stateOrNameText: Text {
        if workout.isPaused {
            return Text("Paused").foregroundStyle(palette.amber)
        }
        if restTimer.isRunning {
            let remaining = TimeInterval(restTimer.remaining(at: now))
            return Text("Resting \(Self.format(remaining))").foregroundStyle(palette.accent)
        }
        return Text(workout.displayName)
    }

    private func plain(_ string: String) -> Text { Text(string) }

    private func bold(_ string: String) -> Text {
        Text(string).fontWeight(.semibold).foregroundStyle(palette.text2)
    }

    private var totalExercises: Int { workout.exercises.count }
    private var totalWorkingSets: Int { workout.workingSetCount }

    private var completedWorkingSets: Int {
        workout.exercises.reduce(0) { count, exercise in
            count + exercise.sets.lazy.filter { !$0.isWarmup && $0.completed }.count
        }
    }

    /// Index of the first exercise not yet fully logged (or `totalExercises`
    /// once every exercise is done) — backs both the caption's "Ex N/total"
    /// and the hairline's done/current/remaining split.
    private var currentExerciseIndex: Int {
        let ordered = workout.orderedExercises
        return ordered.firstIndex(where: { !isFullyLogged($0) }) ?? ordered.count
    }

    /// An exercise counts as fully logged once every one of its sets — warm-up
    /// or working — is checked complete. Exercises with no sets yet don't
    /// count, so adding a fresh exercise can't inflate the fraction.
    private func isFullyLogged(_ exercise: WorkoutExercise) -> Bool {
        !exercise.sets.isEmpty && exercise.sets.allSatisfy(\.completed)
    }

    // MARK: Hairline

    /// Per-exercise progress rule: completed exercises paint solid
    /// ``BanePalette/accent``, the current one shows accent at 40%, everything
    /// after is the muted track color — segment widths weight by each
    /// exercise's set count so a 5-set exercise reads as more of the session
    /// than a 2-set one.
    private var hairline: some View {
        let ordered = workout.orderedExercises
        let weights = ordered.map { max(1, $0.sets.count) }
        let totalWeight = max(1, weights.reduce(0, +))
        let spacing: CGFloat = 2

        return GeometryReader { geo in
            let available = max(0, geo.size.width - spacing * CGFloat(max(0, ordered.count - 1)))
            HStack(spacing: spacing) {
                ForEach(Array(ordered.enumerated()), id: \.element.id) { index, _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(hairlineColor(index: index))
                        .frame(width: available * (Double(weights[index]) / Double(totalWeight)))
                }
            }
        }
        .frame(height: 2)
    }

    private func hairlineColor(index: Int) -> Color {
        if index < currentExerciseIndex { return palette.accent }
        if index == currentExerciseIndex { return palette.accent.opacity(0.4) }
        return palette.surface3
    }

    /// Formats the interval as `M:SS` (or `H:MM:SS` past an hour).
    static func format(_ elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// A minute-grained label for VoiceOver: the visible text updates every
    /// second, but this value only changes once a minute, so it reads as a
    /// live region without announcing every tick.
    static func coarseAccessibilityLabel(_ elapsed: TimeInterval) -> String {
        let totalMinutes = max(0, Int(elapsed)) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        return parts.joined(separator: " ") + " elapsed"
    }
}

// MARK: - Reorder exercises

/// A dedicated, always-in-edit-mode flat list for dragging exercises into a
/// new order — deliberately separate from the main logging list.
///
/// Reordering used to be `.onMove` directly on the main list's `ForEach`, but
/// each row there is a whole `Section` of heterogeneous, variably-sized
/// content (notes field, N sets, two buttons). SwiftUI's List move-gesture
/// geometry assumes a simple, uniform row shape; against that content it
/// produced the wrong section, mis-attributed the drag to a child row (the
/// notes field), or crashed outright. A plain list of exercise names is the
/// uniform shape `.onMove` is built for, so it drives the same
/// ``ActiveWorkoutView/moveExercises(from:to:)`` reliably.
private struct ReorderExercisesView: View {
    @Bindable var workout: Workout
    let onMove: (IndexSet, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.banePalette) private var palette

    var body: some View {
        List {
            ForEach(workout.orderedExercises) { workoutExercise in
                Text(workoutExercise.exercise?.name ?? "Exercise")
                    .font(BaneFont.body(16))
                    .foregroundStyle(palette.text)
                    .listRowBackground(palette.surface)
            }
            .onMove(perform: onMove)
        }
        .listRowSeparatorTint(palette.line)
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Reorder Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
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
    /// Which set's field owns the keyboard, hoisted to the workout level so a
    /// completed rest can move focus across rows (see ``SetFieldFocus``).
    let focusedField: FocusState<SetFieldFocus?>.Binding
    let onAddSet: () -> Void
    /// Inserts a single blank warm-up set ahead of the working sets.
    let onAddWarmupSet: () -> Void
    let onDeleteSets: (IndexSet) -> Void
    let onRemoveExercise: () -> Void
    /// Opens the alternatives picker to swap this exercise for another.
    let onSwap: () -> Void
    /// Fired with the set that was just checked complete.
    let onComplete: (SetEntry) -> Void
    /// Fired with the set that was just un-completed.
    let onUncomplete: (SetEntry) -> Void
    /// Opens the warm-up calculator sheet for this exercise.
    let onOpenWarmups: () -> Void
    /// Links this exercise with the one below into a superset. `nil` when there
    /// is no exercise below to link to.
    let onSupersetWithNext: (() -> Void)?
    /// Detaches this exercise from its superset. `nil` when it isn't in one.
    let onLeaveSuperset: (() -> Void)?

    @Environment(\.banePalette) private var palette

    var body: some View {
        Section {
            TextField(
                "Notes",
                text: $workoutExercise.notes,
                axis: .vertical
            )
            .font(.callout)
            .foregroundStyle(palette.text2)
            .listRowBackground(palette.surface)

            ForEach(workoutExercise.orderedSets) { set in
                SetRow(
                    set: set,
                    previous: previousValues[set.id],
                    focusedField: focusedField,
                    onComplete: onComplete,
                    onUncomplete: onUncomplete
                )
                .listRowBackground(palette.surface2)
            }
            .onDelete(perform: onDeleteSets)

            Button(action: onAddSet) {
                Label("Add Set", systemImage: "plus")
                    .font(.callout)
                    .foregroundStyle(palette.accent)
            }
            .listRowBackground(palette.surface)

            Button(action: onAddWarmupSet) {
                Label("Add Warm-up Set", systemImage: "flame")
                    .font(.callout)
                    .foregroundStyle(palette.amber)
            }
            .listRowBackground(palette.surface)
        } header: {
            VStack(alignment: .leading, spacing: 6) {
                if let superset {
                    supersetBadge(superset)
                }
                HStack {
                    Text(workoutExercise.exercise?.name ?? "Exercise")
                        .baneHeading(13)
                        .foregroundStyle(palette.text2)
                    Spacer()
                    actionMenu
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
    }

    /// What the user did last session, keyed by current set id, for the "last
    /// time" ghost values. Recomputed per render — cheap for realistic set counts.
    private var previousValues: [UUID: PreviousSession.SetValue] {
        PreviousSession.lastValues(for: workoutExercise)
    }

    /// The superset identity chip: its letter and this exercise's position
    /// within the group (e.g. "SUPERSET A · 1 of 2").
    private func supersetBadge(_ superset: SupersetContext) -> some View {
        Label(
            "Superset \(superset.letter) · \(superset.index) of \(superset.count)",
            systemImage: "link"
        )
        .font(BaneFont.mono(11, weight: .semibold))
        .textCase(nil)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(palette.steel.opacity(0.18), in: Capsule())
        .foregroundStyle(palette.steel)
        .accessibilityLabel(
            "Superset \(superset.letter), exercise \(superset.index) of \(superset.count)"
        )
    }

    /// The single overflow menu for this exercise: warm-up, swap, superset
    /// grouping, rest override, and remove — replacing what used to be five
    /// separate icon buttons crowding the header row.
    private var actionMenu: some View {
        Menu {
            Button(action: onOpenWarmups) {
                Label("Add Warm-up Sets", systemImage: "flame")
            }
            Button(action: onSwap) {
                Label("Swap Exercise", systemImage: "arrow.left.arrow.right")
            }
            if let onSupersetWithNext {
                Button(action: onSupersetWithNext) {
                    Label("Superset with Next", systemImage: "link")
                }
            }
            if let onLeaveSuperset {
                Button(role: .destructive, action: onLeaveSuperset) {
                    Label("Remove from Superset", systemImage: "minus.circle")
                }
            }
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
                    Label("Rest: \(restLabel(for: exercise))", systemImage: "timer")
                }
            }
            Divider()
            Button(role: .destructive, action: onRemoveExercise) {
                Label("Remove Exercise", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.callout)
                .foregroundStyle(palette.text2)
        }
        .accessibilityLabel("Exercise actions")
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
    /// Which set's field owns the keyboard, hoisted to the workout level (see
    /// ``SetFieldFocus``) rather than local to this row — a per-row
    /// `@FocusState` has no way to receive focus moved in from outside it,
    /// which a completed rest needs to do when it advances to the next set.
    let focusedField: FocusState<SetFieldFocus?>.Binding
    /// Called with this set when it transitions into the completed state.
    let onComplete: (SetEntry) -> Void
    /// Called with this set when it transitions out of the completed state.
    let onUncomplete: (SetEntry) -> Void

    /// The unit weights are displayed and entered in; storage stays pounds.
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback

    /// Drives the per-set plate-calculator sheet.
    @State private var isShowingPlateCalculator = false

    /// The weight field's live editing value while it has focus, letting the
    /// field go genuinely empty mid-edit. `TextField(value:format:)` bound
    /// directly to `set.weight` (a non-optional `Double`) can't represent "no
    /// text yet" — an empty string fails to parse, so the field re-renders
    /// from the unchanged binding and the old number appears to pop back in
    /// the instant the user deletes it (ba-wdd). Routing through this
    /// optional while focused lets the field stay blank; blurring falls back
    /// to reading `set.weight` directly, which re-seeds/commits the display.
    @State private var weightFieldOverride: Double?

    @Environment(\.banePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            fields
                .padding(.vertical, 6)
                .background(set.completed ? palette.accentWash : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(set.completed ? palette.accent.opacity(0.32) : .clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
                    .font(BaneFont.mono(13, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(
                        set.isWarmup ? palette.amber.opacity(0.2) : palette.surface3,
                        in: Circle()
                    )
                    .foregroundStyle(set.isWarmup ? palette.amber : palette.text3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isWarmup ? "Warm-up set" : "Working set \(set.order + 1)")
            .accessibilityHint("Toggles warm-up")

            fieldColumn(
                title: "Reps",
                onDecrement: { set.reps = max(0, set.reps - 1) },
                onIncrement: { set.reps += 1 }
            ) {
                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .focused(focusedField, equals: SetFieldFocus(setID: set.id, field: .reps))
            }

            fieldColumn(
                title: "Weight (\(weightUnit.abbreviation))",
                onDecrement: {
                    set.weight = max(0, set.weight - weightUnit.toPounds(1))
                    weightFieldOverride = weightUnit.fromPounds(set.weight)
                },
                onIncrement: {
                    set.weight += weightUnit.toPounds(1)
                    weightFieldOverride = weightUnit.fromPounds(set.weight)
                }
            ) {
                TextField("0", value: weightFieldBinding, format: .number)
                    .keyboardType(.decimalPad)
                    .focused(focusedField, equals: SetFieldFocus(setID: set.id, field: .weight))
                    .onChange(of: isWeightFieldFocused) { _, focused in
                        if focused {
                            weightFieldOverride = weightUnit.fromPounds(set.weight)
                        }
                    }
            }

            rpeColumn

            Button {
                isShowingPlateCalculator = true
            } label: {
                Image(systemName: "circle.grid.2x1.fill")
                    .font(.body)
                    .foregroundStyle(palette.text3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Plate calculator")
            .accessibilityHint("Breaks this weight into plates per side")

            Button {
                focusedField.wrappedValue = nil
                set.completed.toggle()
                if set.completed {
                    set.completedAt = Date()
                    onComplete(set)
                } else {
                    set.completedAt = nil
                    onUncomplete(set)
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(set.completed ? palette.accent : .clear)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(set.completed ? .clear : palette.lineStrong, lineWidth: 1)
                    if set.completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.onAccent)
                    }
                }
                .frame(width: 26, height: 26)
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
            .font(BaneFont.mono(11))
            .foregroundStyle(palette.text3)
            .padding(.leading, 38)
            .accessibilityLabel("Last time \(previous.reps) reps at \(weight)")
    }

    /// Whether the weight field currently owns the keyboard.
    private var isWeightFieldFocused: Bool {
        focusedField.wrappedValue == SetFieldFocus(setID: set.id, field: .weight)
    }

    /// The optional-`Double` view the weight `TextField` binds to: `weightFieldOverride`
    /// while focused (so clearing the text reads as `nil`, not a failed parse of the
    /// old value), `set.weight` otherwise. Writes with a real value commit immediately;
    /// a cleared field leaves `set.weight` untouched until the user types a replacement.
    private var weightFieldBinding: Binding<Double?> {
        Binding(
            get: { isWeightFieldFocused ? weightFieldOverride : weightUnit.fromPounds(set.weight) },
            set: { newValue in
                weightFieldOverride = newValue
                if let newValue {
                    set.weight = weightUnit.toPounds(newValue)
                }
            }
        )
    }

    /// A titled numeric entry column: a bordered box with –/+ step buttons
    /// flanking a centered value, matching `.bn-numf`'s stepper affordance.
    private func fieldColumn(
        title: String,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void,
        @ViewBuilder field: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(BaneFont.mono(10))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(palette.text3)
            HStack(spacing: 0) {
                stepButton(systemImage: "minus", label: "Decrease \(title)", action: onDecrement)
                field()
                    .font(BaneFont.mono(15, weight: .medium))
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                stepButton(systemImage: "plus", label: "Increase \(title)", action: onIncrement)
            }
            .frame(height: 34)
            .background(palette.surface3, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A step button sized to fit inside ``fieldColumn``'s 34pt row rather than
    /// the 44pt touch target `BaneNumberField` uses standalone — this row
    /// already packs six controls (warm-up, reps, weight, RPE, plates, done).
    private func stepButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.text3)
                .frame(width: 20, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Optional RPE picker, matching the titled column layout of reps/weight.
    /// Bounded to the 6–10 half-point scale, with a dash for "not recorded".
    private var rpeColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("RPE")
                .font(BaneFont.mono(10))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(palette.text3)
            Menu {
                Picker("RPE", selection: $set.rpe) {
                    Text("—").tag(Double?.none)
                    ForEach(RPEScale.values, id: \.self) { value in
                        Text(RPEScale.label(value)).tag(Double?.some(value))
                    }
                }
            } label: {
                Text(set.rpe.map(RPEScale.label) ?? "—")
                    .font(BaneFont.mono(15, weight: .medium))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(palette.surface3, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
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
