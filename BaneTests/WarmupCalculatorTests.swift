import XCTest
@testable import Bane

/// Unit tests for ``WarmupCalculator`` — the pure warm-up ramp math behind the
/// warm-up calculator sheet (ba-07l.7).
///
/// The calculator is a pure function over numbers, so these assert the ladder
/// scales, rounds, floors at the bar, and prunes redundant rungs as documented.
final class WarmupCalculatorTests: XCTestCase {

    private let standard = [
        WarmupCalculator.Step(percentage: 0.40, reps: 8),
        WarmupCalculator.Step(percentage: 0.60, reps: 5),
        WarmupCalculator.Step(percentage: 0.80, reps: 3),
    ]

    // MARK: - Scaling & rounding

    /// Each rung is the working weight × its percentage, rounded to the increment.
    func testScalesAndRoundsEachRung() {
        let sets = WarmupCalculator.warmupSets(
            workingWeight: 200,
            scheme: standard,
            rounding: 5
        )

        XCTAssertEqual(sets.map(\.weight), [80, 120, 160])
        XCTAssertEqual(sets.map(\.reps), [8, 5, 3])
        XCTAssertEqual(sets.map(\.percentage), [0.40, 0.60, 0.80])
    }

    /// Raw weights round to the nearest increment, not merely truncate.
    func testRoundsToNearestIncrement() {
        // 185 × 0.40 = 74 → 75; 185 × 0.60 = 111 → 110; 185 × 0.80 = 148 → 150.
        let sets = WarmupCalculator.warmupSets(
            workingWeight: 185,
            scheme: standard,
            rounding: 5
        )

        XCTAssertEqual(sets.map(\.weight), [75, 110, 150])
    }

    /// A finer increment yields finer weights.
    func testHonorsRoundingIncrement() {
        let sets = WarmupCalculator.warmupSets(
            workingWeight: 185,
            scheme: standard,
            rounding: 2.5
        )

        // 74 → 75 (nearest 2.5), 111 → 110, 148 → 147.5.
        XCTAssertEqual(sets.map(\.weight), [75, 110, 147.5])
    }

    // MARK: - Bar floor

    /// No rung drops below the bar; the ladder floors there.
    func testFloorsAtBarWeight() {
        // 95 × 0.40 = 38 → 40, below a 45 bar → floored to 45.
        let sets = WarmupCalculator.warmupSets(
            workingWeight: 95,
            scheme: standard,
            rounding: 5,
            barWeight: 45
        )

        XCTAssertEqual(sets.first?.weight, 45)
        XCTAssertTrue(sets.allSatisfy { $0.weight >= 45 })
    }

    /// A working weight at or below the bar has no warm-up ladder.
    func testWorkingWeightAtOrBelowBarYieldsNoSets() {
        XCTAssertTrue(
            WarmupCalculator.warmupSets(
                workingWeight: 45,
                scheme: standard,
                barWeight: 45
            ).isEmpty
        )
    }

    // MARK: - Pruning

    /// Rungs that round to or above the working weight are dropped.
    func testDropsRungsAtOrAboveWorkingWeight() {
        let steep = [
            WarmupCalculator.Step(percentage: 0.50, reps: 5),
            WarmupCalculator.Step(percentage: 1.00, reps: 1),
        ]
        let sets = WarmupCalculator.warmupSets(workingWeight: 100, scheme: steep, rounding: 5)

        XCTAssertEqual(sets.count, 1)
        XCTAssertEqual(sets.first?.weight, 50)
    }

    /// Rungs that round to the same weight as the previous kept rung collapse,
    /// so the ladder strictly ascends.
    func testCollapsesDuplicateRoundedRungs() {
        // At a light working weight with coarse rounding, 0.40 (→10) and 0.60
        // (→10) collapse to one rung, and 0.80 (→20) hits the working weight and
        // is dropped — leaving a single, strictly ascending rung.
        let sets = WarmupCalculator.warmupSets(
            workingWeight: 20,
            scheme: standard,
            rounding: 10
        )

        XCTAssertEqual(sets.map(\.weight), [10])
    }

    // MARK: - roundToIncrement

    func testRoundToIncrementRoundsToNearest() {
        XCTAssertEqual(WarmupCalculator.roundToIncrement(112, increment: 5), 110)
        XCTAssertEqual(WarmupCalculator.roundToIncrement(113, increment: 5), 115)
        XCTAssertEqual(WarmupCalculator.roundToIncrement(146, increment: 2.5), 145)
    }

    /// A non-positive increment falls back to whole-number rounding.
    func testRoundToIncrementFallsBackForNonPositive() {
        XCTAssertEqual(WarmupCalculator.roundToIncrement(112.6, increment: 0), 113)
    }

    // MARK: - Preferences

    /// A known ramp id resolves; an unknown id falls back to the default.
    func testSchemeLookupFallsBackToDefault() {
        XCTAssertEqual(WarmupPreferences.scheme(id: "minimal").id, "minimal")
        XCTAssertEqual(
            WarmupPreferences.scheme(id: "does-not-exist").id,
            WarmupPreferences.fallbackSchemeID
        )
    }
}
