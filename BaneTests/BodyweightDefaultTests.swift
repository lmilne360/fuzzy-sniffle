import SwiftData
import XCTest
@testable import Bane

/// Tests for defaulting a bodyweight exercise's set weight to the user's
/// recorded body weight (ba-bs3).
///
/// `BodyweightDefault.weight` is pure, so most cases are asserted directly;
/// `ManualWarmup.insert(into:bodyWeight:)` is exercised through SwiftData to
/// confirm the default reaches the actually-inserted set.
@MainActor
final class BodyweightDefaultTests: XCTestCase {

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

    private func makeExercise(equipment: Equipment) -> Exercise {
        let exercise = Exercise(
            name: "Push-Up", category: .chest, primaryMuscle: .chest, equipment: equipment
        )
        context.insert(exercise)
        return exercise
    }

    // MARK: - BodyweightDefault.weight

    /// A bodyweight exercise with a recorded body weight defaults to it.
    func testBodyweightExerciseDefaultsToBodyWeight() {
        let pushUp = makeExercise(equipment: .bodyweight)

        XCTAssertEqual(
            BodyweightDefault.weight(for: pushUp, bodyWeight: 180, fallback: 0),
            180
        )
    }

    /// A bodyweight exercise with no recorded body weight falls back unchanged.
    func testBodyweightExerciseWithNoBodyWeightFallsBack() {
        let pushUp = makeExercise(equipment: .bodyweight)

        XCTAssertEqual(
            BodyweightDefault.weight(for: pushUp, bodyWeight: nil, fallback: 0),
            0
        )
    }

    /// A weighted exercise ignores body weight entirely, even when recorded.
    func testWeightedExerciseIgnoresBodyWeight() {
        let benchPress = makeExercise(equipment: .barbell)

        XCTAssertEqual(
            BodyweightDefault.weight(for: benchPress, bodyWeight: 180, fallback: 0),
            0
        )
    }

    /// No exercise at all (a still-loading reference) falls back unchanged.
    func testNoExerciseFallsBack() {
        XCTAssertEqual(
            BodyweightDefault.weight(for: nil, bodyWeight: 180, fallback: 45),
            45
        )
    }

    /// A non-zero fallback (e.g. a copied-forward previous weight) passes
    /// through untouched when there's no body weight to default to.
    func testFallbackIsPreservedWhenNotDefaulting() {
        let benchPress = makeExercise(equipment: .barbell)

        XCTAssertEqual(
            BodyweightDefault.weight(for: benchPress, bodyWeight: nil, fallback: 135),
            135
        )
    }

    // MARK: - ManualWarmup.insert(bodyWeight:)

    /// A manually-added warm-up set on a bodyweight exercise seeds its weight
    /// from the supplied body weight rather than zero, flagged as a suggestion
    /// so the UI shows it as placeholder text rather than a real value (ba-jcb).
    func testManualWarmupSeedsBodyWeightForBodyweightExercise() {
        let pushUp = makeExercise(equipment: .bodyweight)
        let workoutExercise = WorkoutExercise(order: 0, exercise: pushUp)
        context.insert(workoutExercise)

        let warmup = ManualWarmup.insert(into: workoutExercise, bodyWeight: 180)

        XCTAssertEqual(warmup.weight, 180)
        XCTAssertTrue(warmup.weightIsSuggested)
    }

    /// The same insertion on a weighted exercise stays at zero, unaffected by
    /// whatever body weight happens to be on hand — and isn't flagged as a
    /// suggestion, since there's nothing suggested to show.
    func testManualWarmupIgnoresBodyWeightForWeightedExercise() {
        let benchPress = makeExercise(equipment: .barbell)
        let workoutExercise = WorkoutExercise(order: 0, exercise: benchPress)
        context.insert(workoutExercise)

        let warmup = ManualWarmup.insert(into: workoutExercise, bodyWeight: 180)

        XCTAssertEqual(warmup.weight, 0)
        XCTAssertFalse(warmup.weightIsSuggested)
    }
}
