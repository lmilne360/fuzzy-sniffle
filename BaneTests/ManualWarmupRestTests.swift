import SwiftData
import XCTest
@testable import Bane

/// Tests for manually-added warm-up sets and the warm-up rest default (ba-lq4).
///
/// `ManualWarmup.insert(into:)` is exercised through SwiftData to confirm the
/// ordering contract (warm-ups lead, working sets follow); the pure
/// `RestPreferences.restDuration(...)` rule is asserted directly for the
/// warm-up / working / per-exercise-override precedence.
@MainActor
final class ManualWarmupRestTests: XCTestCase {

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

    /// Builds a `WorkoutExercise` with `workingCount` working sets already in
    /// place, inserted into the context so relationships persist.
    private func exercise(workingCount: Int) -> WorkoutExercise {
        let context = container.mainContext
        let workoutExercise = WorkoutExercise(order: 0)
        context.insert(workoutExercise)
        for index in 0..<workingCount {
            let set = SetEntry(order: index, reps: 8, weight: 135)
            set.workoutExercise = workoutExercise
            workoutExercise.sets.append(set)
        }
        return workoutExercise
    }

    // MARK: - Manual warm-up insertion (Part A)

    /// (1) Adding a warm-up set flags `isWarmup` and orders it ahead of the
    /// working sets, which renumber to follow.
    func testAddWarmupSetFlagsAndOrdersAhead() {
        let workoutExercise = exercise(workingCount: 2)

        let warmup = ManualWarmup.insert(into: workoutExercise)

        XCTAssertTrue(warmup.isWarmup)
        let ordered = workoutExercise.orderedSets
        XCTAssertEqual(ordered.count, 3)
        // Warm-up leads.
        XCTAssertEqual(ordered.first?.id, warmup.id)
        XCTAssertEqual(ordered.first?.order, 0)
        // Working sets follow contiguously, none flagged warm-up.
        XCTAssertEqual(ordered.map(\.isWarmup), [true, false, false])
        XCTAssertEqual(ordered.map(\.order), [0, 1, 2])
    }

    /// A second manual warm-up tails the first, still ahead of the working sets.
    func testSecondWarmupTailsWarmupBlock() {
        let workoutExercise = exercise(workingCount: 2)

        ManualWarmup.insert(into: workoutExercise)
        ManualWarmup.insert(into: workoutExercise)

        let ordered = workoutExercise.orderedSets
        XCTAssertEqual(ordered.map(\.isWarmup), [true, true, false, false])
        XCTAssertEqual(ordered.map(\.order), [0, 1, 2, 3])
    }

    /// Adding a warm-up to an exercise with no working sets simply flags it.
    func testWarmupIntoEmptyExercise() {
        let workoutExercise = exercise(workingCount: 0)

        let warmup = ManualWarmup.insert(into: workoutExercise)

        XCTAssertEqual(workoutExercise.orderedSets.map(\.id), [warmup.id])
        XCTAssertEqual(warmup.order, 0)
        XCTAssertTrue(warmup.isWarmup)
    }

    // MARK: - Rest duration selection (Part B)

    /// (2) A completed warm-up set rests for the warm-up default; a working set
    /// rests for the working default.
    func testWarmupAndWorkingUseTheirDefaults() {
        XCTAssertEqual(
            RestPreferences.restDuration(
                isWarmup: true, exerciseOverride: nil,
                workingDefault: 90, warmupDefault: 60
            ),
            60
        )
        XCTAssertEqual(
            RestPreferences.restDuration(
                isWarmup: false, exerciseOverride: nil,
                workingDefault: 90, warmupDefault: 60
            ),
            90
        )
    }

    /// (3) A per-exercise override wins over both defaults, warm-up or not.
    func testExerciseOverrideWinsOverBothDefaults() {
        XCTAssertEqual(
            RestPreferences.restDuration(
                isWarmup: true, exerciseOverride: 120,
                workingDefault: 90, warmupDefault: 60
            ),
            120
        )
        XCTAssertEqual(
            RestPreferences.restDuration(
                isWarmup: false, exerciseOverride: 120,
                workingDefault: 90, warmupDefault: 60
            ),
            120
        )
    }

    /// The shipped fallbacks: warm-ups rest less than working sets by default.
    func testDefaultFallbacks() {
        XCTAssertEqual(RestPreferences.fallbackSeconds, 90)
        XCTAssertEqual(RestPreferences.fallbackWarmupSeconds, 60)
    }
}
