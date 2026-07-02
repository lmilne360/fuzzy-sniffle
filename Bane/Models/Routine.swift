import Foundation
import SwiftData

/// A reusable workout template: an ordered list of exercises with target set
/// counts. Starting a workout from a routine (ba-32q.8) copies these items
/// into a `Workout`.
@Model
final class Routine {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    /// Owned children. `RoutineItem.order` defines display order — SwiftData
    /// does not guarantee to-many relationship ordering, so read via
    /// ``orderedItems``.
    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
    var items: [RoutineItem]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        items: [RoutineItem] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.items = items
    }

    /// Items in their intended display order.
    var orderedItems: [RoutineItem] {
        items.sorted { $0.order < $1.order }
    }
}

/// One line in a `Routine`: which exercise, how many target sets, and where it
/// sits in the ordered list.
@Model
final class RoutineItem {
    @Attribute(.unique) var id: UUID
    /// Position within the parent routine (ascending).
    var order: Int
    /// Planned number of working sets for this exercise.
    var targetSets: Int
    /// Referenced exercise. Optional so a deleted exercise nullifies rather
    /// than cascading through the routine.
    var exercise: Exercise?
    /// Inverse of ``Routine/items``.
    var routine: Routine?

    init(
        id: UUID = UUID(),
        order: Int,
        targetSets: Int = 3,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.order = order
        self.targetSets = targetSets
        self.exercise = exercise
    }
}
