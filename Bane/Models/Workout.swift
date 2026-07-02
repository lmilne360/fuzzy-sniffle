import Foundation
import SwiftData

/// A logged (or in-progress) training session.
///
/// `date` is the calendar day used for grouping in history; `startedAt` /
/// `finishedAt` bound the actual session. A workout is considered active while
/// `finishedAt` is `nil`.
@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var date: Date
    var startedAt: Date?
    var finishedAt: Date?

    /// Owned children, ordered by `WorkoutExercise.order` (see ``orderedExercises``).
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]

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
        self.exercises = exercises
    }

    /// Exercises in their intended display order.
    var orderedExercises: [WorkoutExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    /// `true` once the session has been completed.
    var isFinished: Bool { finishedAt != nil }
}

/// An exercise performed within a `Workout`, holding its ordered set entries.
@Model
final class WorkoutExercise {
    @Attribute(.unique) var id: UUID
    /// Position within the parent workout (ascending).
    var order: Int
    /// Free-form notes the user records for this exercise during the workout.
    var notes: String
    /// Referenced exercise. Optional so a deleted exercise nullifies rather
    /// than cascading through workout history.
    var exercise: Exercise?
    /// Inverse of ``Workout/exercises``.
    var workout: Workout?

    /// Owned children, ordered by `SetEntry.order` (see ``orderedSets``).
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.workoutExercise)
    var sets: [SetEntry]

    init(
        id: UUID = UUID(),
        order: Int,
        notes: String = "",
        exercise: Exercise? = nil,
        sets: [SetEntry] = []
    ) {
        self.id = id
        self.order = order
        self.notes = notes
        self.exercise = exercise
        self.sets = sets
    }

    /// Sets in their intended display order.
    var orderedSets: [SetEntry] {
        sets.sorted { $0.order < $1.order }
    }
}

/// A single set within a `WorkoutExercise`: the reps and weight actually
/// performed, plus flags for completion and warm-up status.
@Model
final class SetEntry {
    @Attribute(.unique) var id: UUID
    /// Position within the parent exercise (ascending).
    var order: Int
    var reps: Int
    /// Weight in the user's preferred unit (unit handling lives in the UI layer).
    var weight: Double
    /// `true` once the user has checked the set off during the workout.
    var completed: Bool
    /// Warm-up sets are excluded from working-set totals and PRs.
    var isWarmup: Bool
    /// Inverse of ``WorkoutExercise/sets``.
    var workoutExercise: WorkoutExercise?

    init(
        id: UUID = UUID(),
        order: Int,
        reps: Int = 0,
        weight: Double = 0,
        completed: Bool = false,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.order = order
        self.reps = reps
        self.weight = weight
        self.completed = completed
        self.isWarmup = isWarmup
    }
}
