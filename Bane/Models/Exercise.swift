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

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        primaryMuscle: Muscle,
        equipment: Equipment,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.primaryMuscle = primaryMuscle
        self.equipment = equipment
        self.isCustom = isCustom
    }
}
