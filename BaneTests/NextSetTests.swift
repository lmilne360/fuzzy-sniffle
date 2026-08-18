import SwiftData
import XCTest
@testable import Bane

/// Tests for ``NextSet``, the traversal shared by rest-completion
/// focus-advance and the rest sheet's "next up" preview (ba-ymw).
@MainActor
final class NextSetTests: XCTestCase {

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

    /// Builds a `WorkoutExercise` with `completions` sets, one per entry
    /// (`true` = already completed), inserted into a shared `Workout` at
    /// `order`.
    private func exercise(order: Int, completions: [Bool], in workout: Workout) -> WorkoutExercise {
        let context = container.mainContext
        let workoutExercise = WorkoutExercise(order: order)
        workoutExercise.workout = workout
        workout.exercises.append(workoutExercise)
        context.insert(workoutExercise)
        for (index, completed) in completions.enumerated() {
            let set = SetEntry(order: index, reps: 8, weight: 135, completed: completed)
            set.workoutExercise = workoutExercise
            workoutExercise.sets.append(set)
        }
        return workoutExercise
    }

    /// A partially-logged exercise's own next incomplete set wins, regardless
    /// of what follows it in the workout.
    func testNextSetWithinSameExercise() {
        let workout = Workout()
        let current = exercise(order: 0, completions: [true, false, false], in: workout)
        _ = exercise(order: 1, completions: [false], in: workout)

        let next = NextSet.find(after: current, in: workout)

        XCTAssertEqual(next?.workoutExercise.id, current.id)
        XCTAssertEqual(next?.position, 2)
        XCTAssertEqual(next?.total, 3)
        XCTAssertEqual(next?.set.id, current.orderedSets[1].id)
    }

    /// Once every set in the current exercise is complete, the next
    /// exercise's first set is offered.
    func testFallsThroughToNextExerciseWhenCurrentIsFullyLogged() {
        let workout = Workout()
        let current = exercise(order: 0, completions: [true, true], in: workout)
        let following = exercise(order: 1, completions: [false, false], in: workout)

        let next = NextSet.find(after: current, in: workout)

        XCTAssertEqual(next?.workoutExercise.id, following.id)
        XCTAssertEqual(next?.position, 1)
        XCTAssertEqual(next?.total, 2)
        XCTAssertEqual(next?.set.id, following.orderedSets[0].id)
    }

    /// The workout's last exercise, fully logged, has nothing left to preview.
    func testNilWhenLastExerciseIsFullyLogged() {
        let workout = Workout()
        let current = exercise(order: 0, completions: [true], in: workout)

        XCTAssertNil(NextSet.find(after: current, in: workout))
    }

    /// A fully-logged exercise followed by one with no sets yet also has
    /// nothing to preview.
    func testNilWhenNextExerciseHasNoSets() {
        let workout = Workout()
        let current = exercise(order: 0, completions: [true], in: workout)
        _ = exercise(order: 1, completions: [], in: workout)

        XCTAssertNil(NextSet.find(after: current, in: workout))
    }
}
