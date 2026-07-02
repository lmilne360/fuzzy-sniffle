import Foundation
import SwiftData

/// A single exercise definition — either seeded from the built-in library
/// (`isCustom == false`) or created by the user (`isCustom == true`).
///
/// `Exercise` is referenced (not owned) by `RoutineItem` and
/// `WorkoutExercise`, so deleting an exercise nullifies those references
/// rather than cascading; history and routines keep their remaining data.
@Model
final class Exercise {
    /// Stable identity, useful for seeding idempotently and for diffing in views.
    @Attribute(.unique) var id: UUID
    var name: String
    var category: ExerciseCategory
    var primaryMuscle: Muscle
    var equipment: Equipment
    /// `true` for user-created exercises, `false` for the seeded library.
    var isCustom: Bool
    /// Per-exercise rest-timer override, in seconds. `nil` falls back to the
    /// app-wide default (see ``RestTimerController``). Optional so existing
    /// stores migrate automatically.
    var restDuration: Int?

    /// Back-references from routines that use this exercise. Declared so
    /// SwiftData tracks the inverse and can apply the `.nullify` delete rule:
    /// deleting an `Exercise` sets each `RoutineItem.exercise` to `nil` rather
    /// than leaving a dangling reference (ba-dw3).
    @Relationship(deleteRule: .nullify, inverse: \RoutineItem.exercise)
    var routineItems: [RoutineItem] = []

    /// Back-references from logged workouts that use this exercise. Declared so
    /// SwiftData tracks the inverse and nullifies each `WorkoutExercise.exercise`
    /// on delete, preserving workout history (ba-dw3).
    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
    var workoutExercises: [WorkoutExercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        primaryMuscle: Muscle,
        equipment: Equipment,
        isCustom: Bool = false,
        restDuration: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.primaryMuscle = primaryMuscle
        self.equipment = equipment
        self.isCustom = isCustom
        self.restDuration = restDuration
    }
}
