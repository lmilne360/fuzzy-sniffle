import SwiftData
import XCTest
@testable import Bane

/// Tests for swapping an active-workout exercise for an alternative (ba-oy0.4).
///
/// Two contracts are covered: `ExerciseAlternatives.suggestions` (which library
/// exercises are offered as swaps) and `ExerciseSwap.swap` (that reassigning the
/// exercise leaves the logged set structure untouched). The swap is exercised
/// through SwiftData so the relationship carry-over is real.
@MainActor
final class ExerciseSwapTests: XCTestCase {

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

    private func makeExercise(
        name: String,
        primaryMuscle: Muscle,
        equipment: Equipment = .barbell
    ) -> Exercise {
        let exercise = Exercise(
            name: name, category: .chest, primaryMuscle: primaryMuscle, equipment: equipment
        )
        context.insert(exercise)
        return exercise
    }

    // MARK: - suggestions

    /// Only same-primary-muscle exercises are suggested, and the source itself is
    /// never offered as its own alternative.
    func testSuggestionsShareMuscleAndExcludeSource() {
        let bench = makeExercise(name: "Bench Press", primaryMuscle: .chest)
        let dips = makeExercise(name: "Dips", primaryMuscle: .chest)
        let flyes = makeExercise(name: "Cable Flyes", primaryMuscle: .chest)
        let curl = makeExercise(name: "Biceps Curl", primaryMuscle: .biceps)

        let library = [bench, dips, flyes, curl]
        let suggestions = ExerciseAlternatives.suggestions(for: bench, in: library)
        let names = Set(suggestions.map(\.name))

        XCTAssertEqual(names, ["Dips", "Cable Flyes"])
        XCTAssertFalse(names.contains("Bench Press"))
        XCTAssertFalse(names.contains("Biceps Curl"))
    }

    /// An exercise with no same-muscle siblings gets no suggestions.
    func testSuggestionsEmptyWhenNoSiblings() {
        let curl = makeExercise(name: "Biceps Curl", primaryMuscle: .biceps)
        let bench = makeExercise(name: "Bench Press", primaryMuscle: .chest)

        XCTAssertTrue(
            ExerciseAlternatives.suggestions(for: curl, in: [curl, bench]).isEmpty
        )
    }

    // MARK: - swap

    /// Swapping repoints the exercise while leaving every logged set — reps,
    /// weight, completion, warm-up flag, order — exactly as it was.
    func testSwapPreservesLoggedSets() {
        let bench = makeExercise(name: "Bench Press", primaryMuscle: .chest)
        let dips = makeExercise(name: "Dips", primaryMuscle: .chest)

        let workout = Workout(startedAt: .now)
        context.insert(workout)
        let workoutExercise = WorkoutExercise(order: 0, notes: "felt strong", exercise: bench)
        workoutExercise.workout = workout
        workout.exercises.append(workoutExercise)
        for set in [
            SetEntry(order: 0, reps: 10, weight: 45, isWarmup: true),
            SetEntry(order: 1, reps: 8, weight: 135, completed: true),
            SetEntry(order: 2, reps: 6, weight: 155),
        ] {
            set.workoutExercise = workoutExercise
            workoutExercise.sets.append(set)
        }
        let originalSetIDs = workoutExercise.orderedSets.map(\.id)

        ExerciseSwap.swap(workoutExercise, to: dips)

        XCTAssertEqual(workoutExercise.exercise?.id, dips.id)
        XCTAssertEqual(workoutExercise.notes, "felt strong")
        // Set structure carries over unchanged, same rows in the same order.
        XCTAssertEqual(workoutExercise.orderedSets.map(\.id), originalSetIDs)
        XCTAssertEqual(workoutExercise.orderedSets.map(\.reps), [10, 8, 6])
        XCTAssertEqual(workoutExercise.orderedSets.map(\.weight), [45, 135, 155])
        XCTAssertEqual(workoutExercise.orderedSets.map(\.isWarmup), [true, false, false])
        XCTAssertEqual(workoutExercise.orderedSets.map(\.completed), [false, true, false])
    }

    /// The swap updates both sides of the relationship: the new exercise now
    /// references the workout exercise, the old one no longer does.
    func testSwapUpdatesInverseRelationship() {
        let bench = makeExercise(name: "Bench Press", primaryMuscle: .chest)
        let dips = makeExercise(name: "Dips", primaryMuscle: .chest)

        let workout = Workout(startedAt: .now)
        context.insert(workout)
        let workoutExercise = WorkoutExercise(order: 0, exercise: bench)
        workoutExercise.workout = workout
        workout.exercises.append(workoutExercise)

        ExerciseSwap.swap(workoutExercise, to: dips)

        XCTAssertTrue(dips.workoutExercises.contains { $0.id == workoutExercise.id })
        XCTAssertFalse(bench.workoutExercises.contains { $0.id == workoutExercise.id })
    }
}
