import SwiftData
import XCTest
@testable import Bane

/// Tests for pruning incomplete sets when a workout finishes (ba-eof).
///
/// `WorkoutFinish.pruneIncompleteSets(in:context:)` is exercised through
/// SwiftData so deletion and renumbering are real: every `SetEntry` never
/// marked complete (warm-ups included) is discarded, surviving sets renumber,
/// and any exercise left with zero sets is removed too.
@MainActor
final class WorkoutFinishTests: XCTestCase {

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

    private var context: ModelContext { container.mainContext }

    @discardableResult
    private func addExercise(
        to workout: Workout,
        order: Int,
        sets: [(completed: Bool, isWarmup: Bool)]
    ) -> WorkoutExercise {
        let workoutExercise = WorkoutExercise(order: order)
        workoutExercise.workout = workout
        workout.exercises.append(workoutExercise)
        for (index, spec) in sets.enumerated() {
            let set = SetEntry(order: index, completed: spec.completed, isWarmup: spec.isWarmup)
            set.workoutExercise = workoutExercise
            workoutExercise.sets.append(set)
        }
        return workoutExercise
    }

    /// A mix of completed and incomplete sets (including an incomplete
    /// warm-up) keeps only the completed ones, renumbered contiguously.
    func testKeepsOnlyCompletedSetsAndRenumbers() {
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        let exercise = addExercise(
            to: workout,
            order: 0,
            sets: [
                (completed: false, isWarmup: true),
                (completed: true, isWarmup: false),
                (completed: false, isWarmup: false),
                (completed: true, isWarmup: false),
            ]
        )

        let result = WorkoutFinish.pruneIncompleteSets(in: workout, context: context)

        XCTAssertTrue(result)
        XCTAssertEqual(exercise.orderedSets.map(\.completed), [true, true])
        XCTAssertEqual(exercise.orderedSets.map(\.order), [0, 1])
    }

    /// An exercise left with zero sets after pruning is removed entirely, and
    /// the remaining exercises' `order` stays contiguous.
    func testRemovesExerciseEmptiedByPruning() {
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        addExercise(to: workout, order: 0, sets: [(completed: true, isWarmup: false)])
        let allIncomplete = addExercise(
            to: workout, order: 1, sets: [(completed: false, isWarmup: false), (completed: false, isWarmup: true)]
        )
        addExercise(to: workout, order: 2, sets: [(completed: true, isWarmup: false)])

        let result = WorkoutFinish.pruneIncompleteSets(in: workout, context: context)

        XCTAssertTrue(result)
        XCTAssertFalse(workout.exercises.contains { $0.id == allIncomplete.id })
        XCTAssertEqual(workout.orderedExercises.map(\.order), [0, 1])
    }

    /// Pruning an exercise out of a superset pair dissolves the group rather
    /// than leaving the survivor referencing a partner that no longer exists.
    func testDissolvesSupersetWhenPartnerIsPrunedAway() {
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        let group = UUID()
        let survivor = addExercise(to: workout, order: 0, sets: [(completed: true, isWarmup: false)])
        let pruned = addExercise(to: workout, order: 1, sets: [(completed: false, isWarmup: false)])
        survivor.supersetGroup = group
        pruned.supersetGroup = group

        WorkoutFinish.pruneIncompleteSets(in: workout, context: context)

        XCTAssertNil(survivor.supersetGroup)
    }

    /// Finishing with nothing ever marked complete does not touch the
    /// workout at all — pruning would discard everything, so the caller
    /// decides what happens instead (block, or discard outright).
    func testReturnsFalseAndTouchesNothingWhenNothingCompleted() {
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        addExercise(to: workout, order: 0, sets: [(completed: false, isWarmup: false), (completed: false, isWarmup: true)])

        let result = WorkoutFinish.pruneIncompleteSets(in: workout, context: context)

        XCTAssertFalse(result)
        XCTAssertEqual(workout.exercises.count, 1)
        XCTAssertEqual(workout.exercises.first?.sets.count, 2)
    }
}
