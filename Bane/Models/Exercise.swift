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
    /// CloudKit sync forbids unique constraints, so uniqueness rests on UUID
    /// generation rather than a store-enforced index. Every stored property
    /// carries a default value — another CloudKit requirement.
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

    // MARK: Inverse relationships
    //
    // These back-references exist for two reasons: CloudKit requires every
    // relationship to have an inverse, and the `.nullify` delete rule only fires
    // when the inverse is present. With them, deleting an `Exercise` nullifies
    // the forward references on routine items, workout history, and PR rows
    // instead of leaving them dangling (fixes ba-dw3). All are optional per
    // CloudKit's to-many rule; nothing reads them directly, so no computed view
    // is needed.

    /// Routine lines that reference this exercise. Inverse of ``RoutineItem/exercise``.
    @Relationship(deleteRule: .nullify, inverse: \RoutineItem.exercise)
    var routineItems: [RoutineItem]?

    /// Workout-history entries that reference this exercise. Inverse of ``WorkoutExercise/exercise``.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
    var workoutExercises: [WorkoutExercise]?

    /// Cached personal records for this exercise. Inverse of ``PersonalRecord/exercise``.
    @Relationship(deleteRule: .nullify, inverse: \PersonalRecord.exercise)
    var personalRecords: [PersonalRecord]?

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
