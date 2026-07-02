import XCTest
import SwiftData
@testable import Bane

/// Tests for the ready-made program catalog and its instantiation into
/// `Routine`s (ba-oy0.5).
@MainActor
final class ProgramLibraryTests: XCTestCase {
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

    // MARK: - Catalog integrity

    /// The catalog ships with the three advertised programs.
    func testCatalogContainsExpectedPrograms() {
        let ids = ProgramLibrary.catalog.map(\.id)
        XCTAssertEqual(ids, ["stronglifts-5x5", "push-pull-legs", "full-body-beginner"])
    }

    /// Program ids must be unique so `ForEach`/identity stay stable.
    func testProgramIdsAreUnique() {
        let ids = ProgramLibrary.catalog.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    /// Every program must have at least one workout, every workout at least one
    /// exercise, and every exercise a positive set/rep count.
    func testEveryProgramIsWellFormed() {
        for program in ProgramLibrary.catalog {
            XCTAssertFalse(program.workouts.isEmpty, "\(program.name) has no workouts")
            for workout in program.workouts {
                XCTAssertFalse(workout.exercises.isEmpty, "\(workout.name) has no exercises")
                XCTAssertFalse(workout.name.isEmpty)
                for plan in workout.exercises {
                    XCTAssertGreaterThan(plan.setCount, 0, "\(plan.exerciseName) has no sets")
                    XCTAssertGreaterThan(plan.targetReps, 0, "\(plan.exerciseName) has no reps")
                }
            }
        }
    }

    /// CRITICAL: every exercise a program references must exist in the seeded
    /// library, or instantiation would silently drop it. Guards against typos in
    /// the catalog names.
    func testEveryProgramExerciseExistsInLibrary() {
        let libraryNames = Set(ExerciseLibrary.catalog.map { $0.name.lowercased() })
        for program in ProgramLibrary.catalog {
            for workout in program.workouts {
                for plan in workout.exercises {
                    XCTAssertTrue(
                        libraryNames.contains(plan.exerciseName.lowercased()),
                        "\(program.name) → \(workout.name): '\(plan.exerciseName)' is not in ExerciseLibrary"
                    )
                }
            }
        }
    }

    // MARK: - Instantiation

    /// Instantiating StrongLifts 5×5 creates two routines with the right
    /// exercises and 5×5 set/rep targets, all referencing real library exercises.
    func testInstantiateStrongLiftsCreatesRoutinesWithSets() throws {
        ExerciseLibrary.seedIfNeeded(in: context)
        let program = try XCTUnwrap(ProgramLibrary.catalog.first { $0.id == "stronglifts-5x5" })

        let created = ProgramLibrary.instantiate(program, in: context)
        try context.save()

        XCTAssertEqual(created.count, 2, "StrongLifts has two workouts → two routines")

        let workoutA = try XCTUnwrap(created.first)
        XCTAssertEqual(workoutA.name, "StrongLifts 5×5 · Workout A")
        XCTAssertEqual(workoutA.orderedItems.count, 3)

        // Every item resolved to a real exercise and carries 5 sets of 5 reps.
        for item in workoutA.orderedItems {
            XCTAssertNotNil(item.exercise, "Item should reference a seeded exercise")
            XCTAssertEqual(item.orderedSets.count, 5)
            XCTAssertTrue(item.orderedSets.allSatisfy { $0.targetReps == 5 })
            XCTAssertTrue(item.orderedSets.allSatisfy { $0.targetWeight == 0 },
                          "Weights are left for the user to fill in")
        }

        // Items are ordered contiguously from 0.
        XCTAssertEqual(workoutA.orderedItems.map(\.order), [0, 1, 2])

        // The deadlift in Workout B is a single set of five.
        let workoutB = created[1]
        let deadlift = try XCTUnwrap(
            workoutB.orderedItems.first { $0.exercise?.name == "Conventional Deadlift" }
        )
        XCTAssertEqual(deadlift.orderedSets.count, 1)
        XCTAssertEqual(deadlift.orderedSets.first?.targetReps, 5)
    }

    /// The created routines and their children actually persist and can be fetched
    /// back — the instantiated program is a first-class routine.
    func testInstantiatedProgramPersists() throws {
        ExerciseLibrary.seedIfNeeded(in: context)
        let program = try XCTUnwrap(ProgramLibrary.catalog.first { $0.id == "push-pull-legs" })

        ProgramLibrary.instantiate(program, in: context)
        try context.save()

        let routines = try context.fetch(FetchDescriptor<Routine>())
        XCTAssertEqual(routines.count, 3, "PPL has three workouts")
        XCTAssertTrue(routines.contains { $0.name == "PPL · Push" })
        XCTAssertTrue(routines.contains { $0.name == "PPL · Legs" })

        // Total item count matches the catalog (5 + 5 + 5).
        let items = try context.fetchCount(FetchDescriptor<RoutineItem>())
        XCTAssertEqual(items, 15)
    }

    /// Instantiation reuses the library's `Exercise` objects rather than creating
    /// new ones — the exercise count is unchanged after adding a program.
    func testInstantiateDoesNotCreateNewExercises() throws {
        ExerciseLibrary.seedIfNeeded(in: context)
        let before = try context.fetchCount(FetchDescriptor<Exercise>())

        let program = try XCTUnwrap(ProgramLibrary.catalog.first)
        ProgramLibrary.instantiate(program, in: context)
        try context.save()

        let after = try context.fetchCount(FetchDescriptor<Exercise>())
        XCTAssertEqual(before, after, "Programs reference existing exercises, never fabricate them")
    }

    /// With no library seeded, unknown exercises are skipped: the routines are
    /// still created (empty) rather than crashing or inventing exercises.
    func testInstantiateWithoutLibrarySkipsUnknownExercises() throws {
        let program = try XCTUnwrap(ProgramLibrary.catalog.first { $0.id == "full-body-beginner" })

        let created = ProgramLibrary.instantiate(program, in: context)
        try context.save()

        XCTAssertEqual(created.count, 1)
        XCTAssertTrue(created[0].orderedItems.isEmpty,
                      "No library means no matches, so the routine has no items")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 0)
    }

    /// Instantiating the same program twice creates two independent sets of
    /// routines (users can add a program more than once).
    func testInstantiateTwiceCreatesIndependentRoutines() throws {
        ExerciseLibrary.seedIfNeeded(in: context)
        let program = try XCTUnwrap(ProgramLibrary.catalog.first { $0.id == "full-body-beginner" })

        ProgramLibrary.instantiate(program, in: context)
        ProgramLibrary.instantiate(program, in: context)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Routine>()), 2)
    }
}
