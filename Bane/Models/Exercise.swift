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
    ///
    /// Not `@Attribute(.unique)`: CloudKit-backed stores forbid unique
    /// constraints, so uniqueness is enforced logically instead — library
    /// seeding is gated on an existing-count check (see ``ExerciseLibrary``).
    /// The inline default keeps the attribute CloudKit-valid (ba-07l.12).
    var id: UUID = UUID()
    var name: String = ""
    var category: ExerciseCategory = ExerciseCategory.other
    var primaryMuscle: Muscle = Muscle.other
    var equipment: Equipment = Equipment.other
    /// `true` for user-created exercises, `false` for the seeded library.
    var isCustom: Bool = false
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

    /// Back-references from cached personal records for this exercise. Declared
    /// so SwiftData tracks the inverse (CloudKit requires every relationship to
    /// have one) and nullifies each `PersonalRecord.exercise` on delete; the
    /// next refresh prunes the orphaned record (ba-07l.12).
    @Relationship(deleteRule: .nullify, inverse: \PersonalRecord.exercise)
    var personalRecords: [PersonalRecord] = []

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
