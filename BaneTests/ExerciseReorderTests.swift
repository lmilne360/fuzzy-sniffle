import SwiftData
import XCTest
@testable import Bane

/// Tests for drag-to-reorder of exercises within a workout (ba-4j8).
///
/// `ExerciseReorder.move(in:from:to:)` is exercised through SwiftData so the
/// contract is real: `order` renumbers to match the dragged sequence while
/// each exercise's own data (its sets, notes, superset membership) travels
/// with it untouched — reordering never touches `WorkoutExercise.sets`.
@MainActor
final class ExerciseReorderTests: XCTestCase {

    /// Retained for the lifetime of each test — the `mainContext` used below is
    /// only valid while its container is alive.
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        container = Persistence.inMemoryContainer()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    /// Builds a workout with `count` exercises (in order), each carrying one
    /// set tagged to its position so set ownership is verifiable post-move.
    private func workout(count: Int) -> Workout {
        let context = container.mainContext
        let workout = Workout()
        context.insert(workout)

        var exercises: [WorkoutExercise] = []
        for index in 0..<count {
            let workoutExercise = WorkoutExercise(order: index, notes: "notes-\(index)")
            workoutExercise.workout = workout
            let set = SetEntry(order: 0, reps: index, weight: Double(index) * 10)
            set.workoutExercise = workoutExercise
            workoutExercise.sets.append(set)
            exercises.append(workoutExercise)
        }
        workout.exercises = exercises
        return workout
    }

    /// Dragging the last exercise to the front moves it there and renumbers
    /// every exercise's `order` to match, without disturbing its notes or sets.
    func testMoveToFrontRenumbersAndPreservesData() {
        let workout = workout(count: 3)
        let dragged = workout.orderedExercises[2]

        ExerciseReorder.move(in: workout, from: IndexSet(integer: 2), to: 0)

        let ordered = workout.orderedExercises
        XCTAssertEqual(ordered.map(\.id), [dragged.id, workout.exercises.first { $0.notes == "notes-0" }!.id, workout.exercises.first { $0.notes == "notes-1" }!.id])
        XCTAssertEqual(ordered.map(\.order), [0, 1, 2])
        XCTAssertEqual(dragged.notes, "notes-2")
        XCTAssertEqual(dragged.sets.first?.reps, 2)
        XCTAssertEqual(dragged.sets.first?.weight, 20)
    }

    /// Moving the first exercise past the last (SwiftUI's onMove destination
    /// convention: `to` is the insertion index *before* the removal collapses
    /// the array) lands it at the end.
    func testMoveToEndRenumbers() {
        let workout = workout(count: 3)
        let dragged = workout.orderedExercises[0]

        ExerciseReorder.move(in: workout, from: IndexSet(integer: 0), to: 3)

        let ordered = workout.orderedExercises
        XCTAssertEqual(ordered.last?.id, dragged.id)
        XCTAssertEqual(ordered.map(\.order), [0, 1, 2])
    }

    /// A move that's already a no-op (dragging a row onto itself) leaves every
    /// exercise's `order` untouched.
    func testNoOpMoveLeavesOrderUnchanged() {
        let workout = workout(count: 3)
        let originalIds = workout.orderedExercises.map(\.id)

        ExerciseReorder.move(in: workout, from: IndexSet(integer: 1), to: 1)

        XCTAssertEqual(workout.orderedExercises.map(\.id), originalIds)
        XCTAssertEqual(workout.orderedExercises.map(\.order), [0, 1, 2])
    }

    /// Superset membership is untouched by the move itself — dissolving a
    /// group the drag splits apart is the caller's job (`normalizeSupersets`
    /// in `ActiveWorkoutView`), not `ExerciseReorder`'s.
    func testSupersetMembershipTravelsWithTheExercise() {
        let workout = workout(count: 3)
        let group = UUID()
        let ordered = workout.orderedExercises
        ordered[0].supersetGroup = group
        ordered[1].supersetGroup = group
        let dragged = ordered[1]

        ExerciseReorder.move(in: workout, from: IndexSet(integer: 1), to: 3)

        XCTAssertEqual(dragged.supersetGroup, group)
    }
}
