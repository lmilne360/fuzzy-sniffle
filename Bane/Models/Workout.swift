import Foundation
import SwiftData

/// A logged (or in-progress) training session.
///
/// `date` is the calendar day used for grouping in history; `startedAt` /
/// `finishedAt` bound the actual session. A workout is considered active while
/// `finishedAt` is `nil`.
@Model
final class Workout {
    var id: UUID = UUID()
    var date: Date = Date.now
    var startedAt: Date?
    var finishedAt: Date?

    /// Owned children, ordered by `WorkoutExercise.order` (see ``orderedExercises``).
    ///
    /// CloudKit requires to-many relationships to be optional, so the persisted
    /// storage is a private optional backing property; ``exercises`` is a
    /// non-optional facade over it that preserves every existing call site
    /// (reads, assignment, and `.append`) unchanged (ba-07l.12).
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    private var storedExercises: [WorkoutExercise]?

    var exercises: [WorkoutExercise] {
        get { storedExercises ?? [] }
        set { storedExercises = newValue }
    }

    init(
        id: UUID = UUID(),
        date: Date = .now,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        exercises: [WorkoutExercise] = []
    ) {
        self.id = id
        self.date = date
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.storedExercises = exercises
    }

    /// Exercises in their intended display order.
    var orderedExercises: [WorkoutExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    /// Ordered exercises collapsed into superset blocks for display.
    ///
    /// Consecutive exercises that share the same non-`nil` ``WorkoutExercise/supersetGroup``
    /// are returned together as one block; every other exercise comes back as a
    /// single-element block. Order follows ``orderedExercises``. A block with two
    /// or more members represents a superset the user alternates between.
    var exerciseGroups: [[WorkoutExercise]] {
        var groups: [[WorkoutExercise]] = []
        for exercise in orderedExercises {
            if let group = exercise.supersetGroup,
               let last = groups.last?.first,
               last.supersetGroup == group {
                groups[groups.count - 1].append(exercise)
            } else {
                groups.append([exercise])
            }
        }
        return groups
    }

    /// `true` once the session has been completed.
    var isFinished: Bool { finishedAt != nil }
}

/// An exercise performed within a `Workout`, holding its ordered set entries.
@Model
final class WorkoutExercise {
    var id: UUID = UUID()
    /// Position within the parent workout (ascending).
    var order: Int = 0
    /// Free-form notes the user records for this exercise during the workout.
    var notes: String = ""
    /// Identifies the superset this exercise belongs to. Exercises sharing the
    /// same non-`nil` id are performed as a superset — the user alternates
    /// between them. `nil` means the exercise stands on its own. Optional so it
    /// stays migration-safe for workouts logged before supersets existed.
    var supersetGroup: UUID?
    /// Referenced exercise. Optional so a deleted exercise nullifies rather
    /// than cascading through workout history.
    var exercise: Exercise?
    /// Inverse of ``Workout/exercises``.
    var workout: Workout?

    /// Owned children, ordered by `SetEntry.order` (see ``orderedSets``).
    ///
    /// Optional backing + non-optional facade for CloudKit compatibility — see
    /// ``Workout/exercises`` for the rationale (ba-07l.12).
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.workoutExercise)
    private var storedSets: [SetEntry]?

    var sets: [SetEntry] {
        get { storedSets ?? [] }
        set { storedSets = newValue }
    }

    init(
        id: UUID = UUID(),
        order: Int,
        notes: String = "",
        exercise: Exercise? = nil,
        supersetGroup: UUID? = nil,
        sets: [SetEntry] = []
    ) {
        self.id = id
        self.order = order
        self.notes = notes
        self.exercise = exercise
        self.supersetGroup = supersetGroup
        self.storedSets = sets
    }

    /// Sets in their intended display order.
    var orderedSets: [SetEntry] {
        sets.sorted { $0.order < $1.order }
    }

    /// `true` when this exercise is part of a superset.
    var isInSuperset: Bool { supersetGroup != nil }
}

/// A single set within a `WorkoutExercise`: the reps and weight actually
/// performed, plus flags for completion and warm-up status.
@Model
final class SetEntry {
    var id: UUID = UUID()
    /// Position within the parent exercise (ascending).
    var order: Int = 0
    var reps: Int = 0
    /// Weight in the user's preferred unit (unit handling lives in the UI layer).
    var weight: Double = 0
    /// `true` once the user has checked the set off during the workout.
    var completed: Bool = false
    /// Warm-up sets are excluded from working-set totals and PRs.
    var isWarmup: Bool = false
    /// Rate of Perceived Exertion for the set (typically 6–10 in 0.5 steps).
    /// Optional — defaults to `nil` so it stays migration-safe for existing sets.
    var rpe: Double?
    /// Inverse of ``WorkoutExercise/sets``.
    var workoutExercise: WorkoutExercise?

    init(
        id: UUID = UUID(),
        order: Int,
        reps: Int = 0,
        weight: Double = 0,
        completed: Bool = false,
        isWarmup: Bool = false,
        rpe: Double? = nil
    ) {
        self.id = id
        self.order = order
        self.reps = reps
        self.weight = weight
        self.completed = completed
        self.isWarmup = isWarmup
        self.rpe = rpe
    }
}
