import Foundation
import SwiftData

/// A reusable workout template: an ordered list of exercises, each with an
/// ordered list of target sets. Starting a workout from a routine (ba-32q.8)
/// copies these items and their per-set targets into a `Workout`.
@Model
final class Routine {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    /// Backing store for ``items``. CloudKit requires to-many relationships be
    /// optional, so the persisted relationship is optional and ``items`` vends a
    /// non-optional view over it.
    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
    private var storedItems: [RoutineItem]?

    /// Owned children. `RoutineItem.order` defines display order — SwiftData
    /// does not guarantee to-many relationship ordering, so read via
    /// ``orderedItems``.
    var items: [RoutineItem] {
        get { storedItems ?? [] }
        set { storedItems = newValue }
    }

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

/// One line in a `Routine`: which exercise, its ordered target sets, and where
/// it sits in the ordered list.
@Model
final class RoutineItem {
    var id: UUID = UUID()
    /// Position within the parent routine (ascending).
    var order: Int = 0
    /// Referenced exercise. Optional so a deleted exercise nullifies rather
    /// than cascading through the routine.
    var exercise: Exercise?
    /// Inverse of ``Routine/items``.
    var routine: Routine?

    /// Backing store for ``sets`` — optional to satisfy CloudKit's to-many rule.
    @Relationship(deleteRule: .cascade, inverse: \RoutineSet.routineItem)
    private var storedSets: [RoutineSet]?

    /// Owned target sets. `RoutineSet.order` defines display order — read via
    /// ``orderedSets``.
    var sets: [RoutineSet] {
        get { storedSets ?? [] }
        set { storedSets = newValue }
    }

    init(
        id: UUID = UUID(),
        order: Int,
        exercise: Exercise? = nil,
        sets: [RoutineSet] = []
    ) {
        self.id = id
        self.order = order
        self.exercise = exercise
        self.sets = sets
    }

    /// Target sets in their intended display order.
    var orderedSets: [RoutineSet] {
        sets.sorted { $0.order < $1.order }
    }
}

/// A single planned set within a `RoutineItem`: the target reps and weight the
/// user intends to hit (e.g. Set 1: 10 reps @ 100 lb). Starting a workout from
/// the routine seeds each `SetEntry` from these targets.
@Model
final class RoutineSet {
    var id: UUID = UUID()
    /// Position within the parent item (ascending).
    var order: Int = 0
    /// Planned repetitions for this set.
    var targetReps: Int = 0
    /// Planned weight in the user's preferred unit (unit handling lives in the
    /// UI layer, matching `SetEntry`).
    var targetWeight: Double = 0
    /// Inverse of ``RoutineItem/sets``.
    var routineItem: RoutineItem?

    init(
        id: UUID = UUID(),
        order: Int,
        targetReps: Int = 0,
        targetWeight: Double = 0
    ) {
        self.id = id
        self.order = order
        self.targetReps = targetReps
        self.targetWeight = targetWeight
    }
}
