import SwiftData
import XCTest
@testable import Bane

/// Tests for the "last time" ghost values surfaced while logging (ba-oy0.1).
///
/// `PreviousSession` is exercised through SwiftData so the relationship
/// traversal is real: which prior session counts (most recent *finished*,
/// warm-ups excluded) and how its sets line up with the current ones.
@MainActor
final class PreviousSessionTests: XCTestCase {

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

    /// A bare exercise, inserted so its inverse relationships track.
    private func makeExercise(name: String = "Bench Press") -> Exercise {
        let exercise = Exercise(
            name: name, category: .chest, primaryMuscle: .chest, equipment: .barbell
        )
        context.insert(exercise)
        return exercise
    }

    /// Builds a workout for `exercise` with the given sets and finish state,
    /// wiring up the relationships and inserting everything into the context.
    @discardableResult
    private func makeWorkout(
        for exercise: Exercise,
        finishedAt: Date?,
        sets: [SetEntry]
    ) -> WorkoutExercise {
        let workout = Workout(startedAt: finishedAt, finishedAt: finishedAt)
        context.insert(workout)

        let workoutExercise = WorkoutExercise(order: 0, exercise: exercise)
        workoutExercise.workout = workout
        workout.exercises.append(workoutExercise)

        for set in sets {
            set.workoutExercise = workoutExercise
            workoutExercise.sets.append(set)
        }
        return workoutExercise
    }

    // MARK: - lastWorkingSets

    /// The most recent finished session's working sets come back in order, with
    /// warm-ups filtered out.
    func testReturnsMostRecentFinishedWorkingSets() {
        let exercise = makeExercise()
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)

        makeWorkout(for: exercise, finishedAt: older, sets: [
            SetEntry(order: 0, reps: 5, weight: 95),
        ])
        makeWorkout(for: exercise, finishedAt: newer, sets: [
            SetEntry(order: 0, reps: 10, weight: 45, isWarmup: true),
            SetEntry(order: 1, reps: 8, weight: 135),
            SetEntry(order: 2, reps: 6, weight: 155),
        ])
        let current = makeWorkout(for: exercise, finishedAt: nil, sets: [
            SetEntry(order: 0, reps: 0, weight: 0),
        ])

        let previous = PreviousSession.lastWorkingSets(for: exercise, excluding: current)

        XCTAssertEqual(previous.map(\.reps), [8, 6])
        XCTAssertEqual(previous.map(\.weight), [135, 155])
    }

    /// An in-progress (unfinished) prior workout is ignored — only finished
    /// sessions count as "last time".
    func testIgnoresUnfinishedSessions() {
        let exercise = makeExercise()
        makeWorkout(for: exercise, finishedAt: nil, sets: [
            SetEntry(order: 0, reps: 12, weight: 200),
        ])
        let current = makeWorkout(for: exercise, finishedAt: nil, sets: [
            SetEntry(order: 0, reps: 0, weight: 0),
        ])

        XCTAssertTrue(
            PreviousSession.lastWorkingSets(for: exercise, excluding: current).isEmpty
        )
    }

    /// The current exercise is never treated as its own previous session.
    func testExcludesCurrentExercise() {
        let exercise = makeExercise()
        let current = makeWorkout(for: exercise, finishedAt: nil, sets: [
            SetEntry(order: 0, reps: 8, weight: 135),
        ])

        XCTAssertTrue(
            PreviousSession.lastWorkingSets(for: exercise, excluding: current).isEmpty
        )
    }

    // MARK: - lastValues

    /// Working sets line up with last session's by position; sets beyond last
    /// session's count and warm-up rows get no ghost value.
    func testLastValuesPairsWorkingSetsByPosition() {
        let exercise = makeExercise()
        makeWorkout(for: exercise, finishedAt: Date(timeIntervalSince1970: 2_000), sets: [
            SetEntry(order: 0, reps: 8, weight: 135),
            SetEntry(order: 1, reps: 6, weight: 155),
        ])
        let warmup = SetEntry(order: 0, reps: 10, weight: 45, isWarmup: true)
        let first = SetEntry(order: 1, reps: 0, weight: 0)
        let second = SetEntry(order: 2, reps: 0, weight: 0)
        let third = SetEntry(order: 3, reps: 0, weight: 0)
        let current = makeWorkout(for: exercise, finishedAt: nil, sets: [warmup, first, second, third])

        let values = PreviousSession.lastValues(for: current)

        XCTAssertNil(values[warmup.id], "Warm-up rows show no ghost value")
        XCTAssertEqual(values[first.id], PreviousSession.SetValue(reps: 8, weight: 135))
        XCTAssertEqual(values[second.id], PreviousSession.SetValue(reps: 6, weight: 155))
        XCTAssertNil(values[third.id], "No prior set for the extra working set")
    }

    /// With no prior finished session, there are no ghost values at all.
    func testLastValuesEmptyWithoutHistory() {
        let exercise = makeExercise()
        let current = makeWorkout(for: exercise, finishedAt: nil, sets: [
            SetEntry(order: 0, reps: 0, weight: 0),
        ])

        XCTAssertTrue(PreviousSession.lastValues(for: current).isEmpty)
    }
}
