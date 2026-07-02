import XCTest
import SwiftData
@testable import Bane

/// Runtime tests for the SwiftData persistence layer (ba-a6x).
///
/// These exercise the parts of the model that a compile-only build can't
/// verify: that a `ModelContainer` can actually be instantiated from
/// ``Persistence/schema``, that the declared cascade / nullify delete rules
/// behave as documented, and that the `orderedX` accessors sort correctly.
///
/// Every test runs on the main actor because ``Persistence`` vends its
/// containers from `@MainActor` context.
@MainActor
final class PersistenceTests: XCTestCase {
    /// A fresh in-memory container per test — data never touches disk and is
    /// discarded when the container deallocates.
    private var container: ModelContainer!

    private var context: ModelContext { container.mainContext }

    override func setUp() {
        super.setUp()
        container = Persistence.inMemoryContainer()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    // MARK: - Container instantiation

    /// The canonical schema must produce a working container, and a round-trip
    /// insert/fetch must persist and read back every declared model type.
    func testContainerInstantiatesAndRoundTripsEveryModel() throws {
        let exercise = Exercise(
            name: "Bench Press",
            category: .chest,
            primaryMuscle: .chest,
            equipment: .barbell
        )
        let routine = Routine(name: "Push Day")
        let workout = Workout()
        context.insert(exercise)
        context.insert(routine)
        context.insert(workout)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Routine>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Workout>()), 1)

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<Exercise>()).first)
        XCTAssertEqual(fetched.name, "Bench Press")
        XCTAssertEqual(fetched.category, .chest)
        XCTAssertEqual(fetched.equipment, .barbell)
    }

    // MARK: - Cascade delete: Routine → RoutineItem → RoutineSet

    func testDeletingRoutineCascadesToItemsAndSets() throws {
        let routine = Routine(name: "Leg Day")
        let item = RoutineItem(order: 0)
        let set1 = RoutineSet(order: 0, targetReps: 10, targetWeight: 100)
        let set2 = RoutineSet(order: 1, targetReps: 8, targetWeight: 110)
        item.sets = [set1, set2]
        routine.items = [item]
        context.insert(routine)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RoutineItem>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RoutineSet>()), 2)

        context.delete(routine)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Routine>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RoutineItem>()), 0,
                       "Deleting a routine should cascade-delete its items")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RoutineSet>()), 0,
                       "Deleting a routine should cascade-delete its items' sets")
    }

    // MARK: - Cascade delete: Workout → WorkoutExercise → SetEntry

    func testDeletingWorkoutCascadesToExercisesAndSets() throws {
        let workout = Workout()
        let exercise = WorkoutExercise(order: 0)
        let entry1 = SetEntry(order: 0, reps: 5, weight: 225)
        let entry2 = SetEntry(order: 1, reps: 5, weight: 225)
        exercise.sets = [entry1, entry2]
        workout.exercises = [exercise]
        context.insert(workout)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutExercise>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SetEntry>()), 2)

        context.delete(workout)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Workout>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutExercise>()), 0,
                       "Deleting a workout should cascade-delete its exercises")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SetEntry>()), 0,
                       "Deleting a workout should cascade-delete its exercises' set entries")
    }

    // MARK: - Nullify on exercise delete

    /// Deleting an `Exercise` must nullify — not cascade through — the
    /// `RoutineItem` that references it; the routine keeps its structure.
    ///
    /// Nullify now fires because `Exercise` declares the inverse relationship
    /// ``Exercise/routineItems`` (added alongside CloudKit sync, which requires
    /// every relationship to have an inverse — this also closed ba-dw3).
    func testDeletingExerciseNullifiesRoutineItemReference() throws {
        let exercise = Exercise(
            name: "Squat",
            category: .legs,
            primaryMuscle: .quads,
            equipment: .barbell
        )
        let routine = Routine(name: "Leg Day")
        let item = RoutineItem(order: 0, exercise: exercise)
        routine.items = [item]
        context.insert(routine)
        context.insert(exercise)
        try context.save()

        context.delete(exercise)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RoutineItem>()), 1,
                       "The routine item should survive its exercise being deleted")
        let survivingItem = try XCTUnwrap(try context.fetch(FetchDescriptor<RoutineItem>()).first)
        XCTAssertNil(survivingItem.exercise,
                     "The item's exercise reference should be nullified, not dangling")
    }

    /// Deleting an `Exercise` must nullify the `WorkoutExercise` reference so
    /// workout history is preserved.
    ///
    /// Nullify fires via the inverse ``Exercise/workoutExercises`` — see
    /// ``testDeletingExerciseNullifiesRoutineItemReference``.
    func testDeletingExerciseNullifiesWorkoutExerciseReference() throws {
        let exercise = Exercise(
            name: "Deadlift",
            category: .back,
            primaryMuscle: .hamstrings,
            equipment: .barbell
        )
        let workout = Workout()
        let workoutExercise = WorkoutExercise(order: 0, exercise: exercise)
        workout.exercises = [workoutExercise]
        context.insert(workout)
        context.insert(exercise)
        try context.save()

        context.delete(exercise)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutExercise>()), 1,
                       "The workout exercise should survive its exercise being deleted")
        let surviving = try XCTUnwrap(try context.fetch(FetchDescriptor<WorkoutExercise>()).first)
        XCTAssertNil(surviving.exercise,
                     "The workout exercise's reference should be nullified, not dangling")
    }

    // MARK: - Ordered accessors

    func testRoutineOrderedItemsSortByOrder() {
        let routine = Routine(name: "Mixed")
        let a = RoutineItem(order: 2)
        let b = RoutineItem(order: 0)
        let c = RoutineItem(order: 1)
        routine.items = [a, b, c]

        XCTAssertEqual(routine.orderedItems.map(\.order), [0, 1, 2])
    }

    func testRoutineItemOrderedSetsSortByOrder() {
        let item = RoutineItem(order: 0)
        item.sets = [
            RoutineSet(order: 2),
            RoutineSet(order: 0),
            RoutineSet(order: 1),
        ]

        XCTAssertEqual(item.orderedSets.map(\.order), [0, 1, 2])
    }

    func testWorkoutOrderedExercisesSortByOrder() {
        let workout = Workout()
        workout.exercises = [
            WorkoutExercise(order: 1),
            WorkoutExercise(order: 2),
            WorkoutExercise(order: 0),
        ]

        XCTAssertEqual(workout.orderedExercises.map(\.order), [0, 1, 2])
    }

    func testWorkoutExerciseOrderedSetsSortByOrder() {
        let exercise = WorkoutExercise(order: 0)
        exercise.sets = [
            SetEntry(order: 1),
            SetEntry(order: 0),
            SetEntry(order: 2),
        ]

        XCTAssertEqual(exercise.orderedSets.map(\.order), [0, 1, 2])
    }

    // MARK: - Body measurements (ba-07l.3)

    /// A body measurement must round-trip through the container, preserving both
    /// the values that were set and the `nil`s for those that were not.
    func testBodyMeasurementRoundTrips() throws {
        let measurement = BodyMeasurement(
            date: .now,
            weight: 181.4,
            bodyFatPercentage: 17.2,
            chest: 42,
            waist: 33,
            notes: "morning, fasted"
        )
        context.insert(measurement)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<BodyMeasurement>()).first)
        XCTAssertEqual(fetched.weight, 181.4)
        XCTAssertEqual(fetched.bodyFatPercentage, 17.2)
        XCTAssertEqual(fetched.chest, 42)
        XCTAssertEqual(fetched.waist, 33)
        XCTAssertEqual(fetched.notes, "morning, fasted")
        XCTAssertNil(fetched.hips, "Fields left unset must persist as nil")
        XCTAssertNil(fetched.leftArm)
    }

    /// `isEmpty` distinguishes a snapshot with no numeric values from one that
    /// records at least a single field.
    func testBodyMeasurementIsEmptyReflectsRecordedValues() {
        XCTAssertTrue(BodyMeasurement().isEmpty,
                      "A measurement with no values should be empty")
        XCTAssertTrue(BodyMeasurement(notes: "just a note").isEmpty,
                      "Notes alone should not make a measurement non-empty")
        XCTAssertFalse(BodyMeasurement(weight: 180).isEmpty,
                       "A single recorded value should make a measurement non-empty")
    }

    /// `recordedFields` returns only the fields that carry a value, in the same
    /// order they appear in `allFields`.
    func testBodyMeasurementRecordedFieldsFiltersNils() {
        let measurement = BodyMeasurement(weight: 180, bodyFatPercentage: 15, waist: 32)

        let labels = measurement.recordedFields.map(\.label)
        XCTAssertEqual(labels, ["Weight", "Body Fat %", "Waist"])
        XCTAssertEqual(measurement.recordedFields.count, 3)
    }

    /// The `@Query` sort used by the Measurements screen orders newest-first.
    func testBodyMeasurementsFetchSortedByDateDescending() throws {
        let older = BodyMeasurement(date: .now.addingTimeInterval(-86_400), weight: 183)
        let newer = BodyMeasurement(date: .now, weight: 181)
        context.insert(older)
        context.insert(newer)
        try context.save()

        var descriptor = FetchDescriptor<BodyMeasurement>()
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.map(\.weight), [181, 183])
    }

    // MARK: - Superset grouping (ba-07l.6)

    /// With no superset ids assigned, every exercise is its own single-element
    /// block, in order.
    func testExerciseGroupsWithoutSupersetsAreAllSolo() {
        let workout = Workout()
        workout.exercises = [
            WorkoutExercise(order: 2),
            WorkoutExercise(order: 0),
            WorkoutExercise(order: 1),
        ]

        let groups = workout.exerciseGroups
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups.map(\.count), [1, 1, 1])
        XCTAssertEqual(groups.map { $0[0].order }, [0, 1, 2])
    }

    /// Consecutive exercises sharing a superset id collapse into one block while
    /// the exercises around them stay solo.
    func testExerciseGroupsCollapsesContiguousSuperset() {
        let group = UUID()
        let workout = Workout()
        workout.exercises = [
            WorkoutExercise(order: 0),
            WorkoutExercise(order: 1, supersetGroup: group),
            WorkoutExercise(order: 2, supersetGroup: group),
            WorkoutExercise(order: 3),
        ]

        let groups = workout.exerciseGroups
        XCTAssertEqual(groups.map(\.count), [1, 2, 1])
        XCTAssertEqual(groups[1].map { $0.supersetGroup }, [group, group])
        XCTAssertTrue(groups[1].allSatisfy { $0.isInSuperset })
    }

    /// The same superset id split by an exercise in between forms two separate
    /// blocks — grouping is contiguity-based, not id-based.
    func testExerciseGroupsDoesNotMergeNonContiguousSameGroup() {
        let group = UUID()
        let workout = Workout()
        workout.exercises = [
            WorkoutExercise(order: 0, supersetGroup: group),
            WorkoutExercise(order: 1),
            WorkoutExercise(order: 2, supersetGroup: group),
        ]

        let groups = workout.exerciseGroups
        XCTAssertEqual(groups.map(\.count), [1, 1, 1])
    }
}
