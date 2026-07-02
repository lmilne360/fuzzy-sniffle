import XCTest
import SwiftData
@testable import Bane

/// Tests for the double-progression logic and its wiring into
/// `Workout.fromProgressive(routine:in:)` (ba-3hk).
///
/// The pure ``ProgressiveOverload/nextTargets(previousWorkingSets:min:max:increment:fallback:)``
/// rule is covered directly with plain values; a second group drives the same
/// rule through SwiftData to confirm history lookup, warm-up exclusion, and the
/// opt-out path behave end to end.
@MainActor
final class ProgressiveOverloadTests: XCTestCase {

    /// Retained for the lifetime of each test — the `mainContext` used by the
    /// integration tests is only valid while its container is alive.
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        container = Persistence.inMemoryContainer()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private let fallback = [
        ProgressiveOverload.SetTarget(reps: 8, weight: 100),
        ProgressiveOverload.SetTarget(reps: 8, weight: 100),
    ]

    private func previous(_ pairs: [(Int, Double)]) -> [ProgressiveOverload.PreviousSet] {
        pairs.map { ProgressiveOverload.PreviousSet(reps: $0.0, weight: $0.1) }
    }

    // MARK: - Pure rule

    /// (1) Every working set reached the top of the range → add the increment to
    /// each set's weight and reset reps to the bottom, keeping the set count.
    func testAllSetsHitMaxIncreasesWeightAndResetsReps() {
        let result = ProgressiveOverload.nextTargets(
            previousWorkingSets: previous([(12, 100), (12, 100)]),
            min: 8, max: 12, increment: 5,
            fallback: fallback
        )

        XCTAssertEqual(result, [
            ProgressiveOverload.SetTarget(reps: 8, weight: 105),
            ProgressiveOverload.SetTarget(reps: 8, weight: 105),
        ])
    }

    /// (2) Mid-range progress → keep the weight and add one rep per set toward
    /// the top of the range.
    func testSubMaxAddsOneRepAtSameWeight() {
        let result = ProgressiveOverload.nextTargets(
            previousWorkingSets: previous([(9, 100), (10, 100)]),
            min: 8, max: 12, increment: 5,
            fallback: fallback
        )

        XCTAssertEqual(result, [
            ProgressiveOverload.SetTarget(reps: 10, weight: 100),
            ProgressiveOverload.SetTarget(reps: 11, weight: 100),
        ])
    }

    /// A set already at the top while another lags does not trigger a weight
    /// bump (not *all* sets cleared the range); the top set is capped at max.
    func testMixedProgressCapsAtMaxWithoutWeightBump() {
        let result = ProgressiveOverload.nextTargets(
            previousWorkingSets: previous([(12, 100), (10, 100)]),
            min: 8, max: 12, increment: 5,
            fallback: fallback
        )

        XCTAssertEqual(result, [
            ProgressiveOverload.SetTarget(reps: 12, weight: 100),
            ProgressiveOverload.SetTarget(reps: 11, weight: 100),
        ])
    }

    /// (3) No prior history → the routine's configured starting targets are
    /// returned unchanged.
    func testNoHistoryUsesFallbackTargets() {
        let result = ProgressiveOverload.nextTargets(
            previousWorkingSets: [],
            min: 8, max: 12, increment: 5,
            fallback: fallback
        )

        XCTAssertEqual(result, fallback)
    }

    /// (4) A set below the floor → hold: keep each set's weight and target the
    /// floor, adding no load.
    func testBelowMinHoldsWeightAndTargetsMin() {
        let result = ProgressiveOverload.nextTargets(
            previousWorkingSets: previous([(6, 100), (9, 100)]),
            min: 8, max: 12, increment: 5,
            fallback: fallback
        )

        XCTAssertEqual(result, [
            ProgressiveOverload.SetTarget(reps: 8, weight: 100),
            ProgressiveOverload.SetTarget(reps: 8, weight: 100),
        ])
    }

    // MARK: - Integration through SwiftData

    private func makeContext() -> ModelContext {
        container.mainContext
    }

    /// Builds a routine with one exercise, a single item, and `sets` starting
    /// targets, inserting everything into `context`.
    @MainActor
    private func makeRoutine(
        in context: ModelContext,
        exercise: Exercise,
        progressive: Bool,
        min: Int? = nil,
        max: Int? = nil,
        increment: Double? = nil,
        starting sets: [(reps: Int, weight: Double)]
    ) -> Routine {
        let routine = Routine(name: "Push", progressiveOverloadEnabled: progressive)
        let item = RoutineItem(
            order: 0,
            exercise: exercise,
            repRangeMin: min,
            repRangeMax: max,
            weightIncrement: increment
        )
        item.sets = sets.enumerated().map { RoutineSet(order: $0.offset, targetReps: $0.element.reps, targetWeight: $0.element.weight) }
        routine.items = [item]
        context.insert(routine)
        return routine
    }

    /// Inserts a finished workout that performed `exercise` with the given
    /// working sets on `date`.
    @MainActor
    private func logFinished(
        in context: ModelContext,
        exercise: Exercise,
        on date: Date,
        sets: [(reps: Int, weight: Double, warmup: Bool)]
    ) {
        let workout = Workout(date: date, startedAt: date, finishedAt: date)
        let performed = WorkoutExercise(order: 0, exercise: exercise)
        performed.sets = sets.enumerated().map {
            SetEntry(order: $0.offset, reps: $0.element.reps, weight: $0.element.weight, completed: true, isWarmup: $0.element.warmup)
        }
        workout.exercises = [performed]
        context.insert(workout)
    }

    /// With the mode enabled and a top-of-range prior session, the seeded
    /// workout comes back at the next weight with reps reset to the floor.
    @MainActor
    func testFromProgressiveBumpsWeightAfterTopOfRangeSession() throws {
        let context = makeContext()
        let bench = Exercise(name: "Bench Press", category: .chest, primaryMuscle: .chest, equipment: .barbell)
        context.insert(bench)
        let routine = makeRoutine(in: context, exercise: bench, progressive: true, min: 8, max: 12, increment: 5,
                                  starting: [(8, 100), (8, 100)])
        logFinished(in: context, exercise: bench, on: .now,
                    sets: [(12, 100, false), (12, 100, false)])
        try context.save()

        let workout = Workout.fromProgressive(routine: routine, in: context)
        let sets = try XCTUnwrap(workout.orderedExercises.first).orderedSets

        XCTAssertEqual(sets.map(\.reps), [8, 8])
        XCTAssertEqual(sets.map(\.weight), [105, 105])
    }

    /// A mid-range prior session adds a rep at the same weight, and warm-up sets
    /// in that session are excluded from the "all reached max" check.
    @MainActor
    func testFromProgressiveAddsRepAndIgnoresWarmups() throws {
        let context = makeContext()
        let squat = Exercise(name: "Squat", category: .legs, primaryMuscle: .quads, equipment: .barbell)
        context.insert(squat)
        let routine = makeRoutine(in: context, exercise: squat, progressive: true, min: 8, max: 12, increment: 10,
                                  starting: [(8, 200)])
        logFinished(in: context, exercise: squat, on: .now,
                    sets: [(5, 45, true), (10, 200, false)])
        try context.save()

        let workout = Workout.fromProgressive(routine: routine, in: context)
        let sets = try XCTUnwrap(workout.orderedExercises.first).orderedSets

        XCTAssertEqual(sets.map(\.reps), [11])
        XCTAssertEqual(sets.map(\.weight), [200])
    }

    /// The most recent finished session wins when history has several.
    @MainActor
    func testFromProgressiveUsesMostRecentSession() throws {
        let context = makeContext()
        let row = Exercise(name: "Row", category: .back, primaryMuscle: .lats, equipment: .barbell)
        context.insert(row)
        let routine = makeRoutine(in: context, exercise: row, progressive: true, min: 8, max: 12, increment: 5,
                                  starting: [(8, 135)])
        logFinished(in: context, exercise: row, on: .now.addingTimeInterval(-86_400),
                    sets: [(12, 135, false)])
        logFinished(in: context, exercise: row, on: .now,
                    sets: [(9, 140, false)])
        try context.save()

        let workout = Workout.fromProgressive(routine: routine, in: context)
        let sets = try XCTUnwrap(workout.orderedExercises.first).orderedSets

        // Most recent was mid-range at 140 → +1 rep, same weight.
        XCTAssertEqual(sets.map(\.reps), [10])
        XCTAssertEqual(sets.map(\.weight), [140])
    }

    /// With no finished history, progressive mode falls back to the routine's
    /// configured starting targets — identical to `Workout.from(routine:)`.
    @MainActor
    func testFromProgressiveWithoutHistoryUsesStartingTargets() throws {
        let context = makeContext()
        let curl = Exercise(name: "Curl", category: .arms, primaryMuscle: .biceps, equipment: .dumbbell)
        context.insert(curl)
        let routine = makeRoutine(in: context, exercise: curl, progressive: true,
                                  starting: [(10, 30), (10, 30)])
        try context.save()

        let workout = Workout.fromProgressive(routine: routine, in: context)
        let sets = try XCTUnwrap(workout.orderedExercises.first).orderedSets

        XCTAssertEqual(sets.map(\.reps), [10, 10])
        XCTAssertEqual(sets.map(\.weight), [30, 30])
    }

    /// With the mode disabled, prior history is ignored entirely — the workout
    /// seeds from the routine's configured targets even though a maxed session
    /// exists.
    @MainActor
    func testFromProgressiveDisabledIgnoresHistory() throws {
        let context = makeContext()
        let press = Exercise(name: "Overhead Press", category: .shoulders, primaryMuscle: .shoulders, equipment: .barbell)
        context.insert(press)
        let routine = makeRoutine(in: context, exercise: press, progressive: false, min: 8, max: 12, increment: 5,
                                  starting: [(8, 95)])
        logFinished(in: context, exercise: press, on: .now,
                    sets: [(12, 95, false)])
        try context.save()

        let workout = Workout.fromProgressive(routine: routine, in: context)
        let sets = try XCTUnwrap(workout.orderedExercises.first).orderedSets

        XCTAssertEqual(sets.map(\.reps), [8])
        XCTAssertEqual(sets.map(\.weight), [95])
    }
}
