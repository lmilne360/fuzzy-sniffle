import XCTest
@testable import Bane

/// Unit tests for ``WeightUnit`` conversion and ``WeightFormat`` rendering — the
/// pure math and formatting behind the lb/kg display toggle (ba-w6o).
///
/// Canonical storage stays in pounds, so these assert the conversion round-trips
/// within the accepted drift and that display strings carry the right unit label.
final class WeightUnitTests: XCTestCase {

    // MARK: - Conversion

    /// Pounds is the canonical unit, so conversion is the identity.
    func testPoundsConversionIsIdentity() {
        XCTAssertEqual(WeightUnit.pounds.fromPounds(135), 135, accuracy: 0.0000001)
        XCTAssertEqual(WeightUnit.pounds.toPounds(135), 135, accuracy: 0.0000001)
    }

    /// A canonical pounds value renders in kilograms via the documented factor —
    /// 100 lb is about 45.36 kg.
    func testFromPoundsToKilograms() {
        XCTAssertEqual(WeightUnit.kilograms.fromPounds(100), 45.359237, accuracy: 0.0001)
    }

    /// A kilogram value converts back to the matching pounds — 45 kg ≈ 99.2 lb.
    func testToPoundsFromKilograms() {
        XCTAssertEqual(WeightUnit.kilograms.toPounds(45), 99.208018, accuracy: 0.0001)
    }

    /// Entering a value in kg and reading it back yields the original kg value:
    /// the round-trip drift stays well below display precision.
    func testKilogramsRoundTrip() {
        let entered = 42.5
        let stored = WeightUnit.kilograms.toPounds(entered)
        let shownAgain = WeightUnit.kilograms.fromPounds(stored)
        XCTAssertEqual(shownAgain, entered, accuracy: 0.0000001)
    }

    /// One kilogram is exactly the conversion factor in pounds.
    func testOneKilogramInPounds() {
        XCTAssertEqual(WeightUnit.kilograms.toPounds(1), WeightUnit.poundsPerKilogram, accuracy: 0.0000001)
    }

    // MARK: - Formatting

    /// A weight formats with its unit label, trimming needless decimals in lb.
    func testWeightFormatPounds() {
        XCTAssertEqual(WeightFormat.weight(100, in: .pounds), "100 lb")
        XCTAssertEqual(WeightFormat.weight(102.5, in: .pounds), "102.5 lb")
    }

    /// A clean kilogram value (built from the exact factor) renders without any
    /// stray decimal and carries the `kg` label.
    func testWeightFormatKilograms() {
        let poundsForForty = WeightUnit.kilograms.toPounds(40)
        XCTAssertEqual(WeightFormat.weight(poundsForForty, in: .kilograms), "40 kg")
    }

    /// The bare value formatter omits the unit label for fields that show it
    /// separately.
    func testValueOmitsUnitLabel() {
        XCTAssertEqual(WeightFormat.value(45, in: .pounds), "45")
        XCTAssertFalse(WeightFormat.value(45, in: .kilograms).contains("kg"))
    }

    /// Volume rounds to whole numbers and appends the unit label.
    func testVolumeFormatIsWholeNumberWithUnit() {
        XCTAssertTrue(WeightFormat.volume(500, in: .pounds).hasSuffix(" lb"))
        XCTAssertTrue(WeightFormat.volume(500, in: .kilograms).hasSuffix(" kg"))
        XCTAssertFalse(WeightFormat.volume(500, in: .kilograms).contains("."))
    }

    // MARK: - Preferences

    /// The default unit is pounds, preserving the app's historical behavior for
    /// installs that have never set the preference.
    func testFallbackUnitIsPounds() {
        XCTAssertEqual(WeightPreferences.fallback, .pounds)
    }
}
