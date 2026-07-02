import XCTest
@testable import Bane

/// Unit tests for ``HealthKitSync`` — the pure mapping logic behind the Apple
/// Health bridge (ba-07l.9).
///
/// The `HKHealthStore` plumbing in ``HealthKitService`` isn't unit-testable, so
/// the interesting decisions live in these platform-agnostic functions: how a
/// finished workout maps to a Health time span, and when an imported bodyweight
/// sample should become a new measurement.
final class HealthKitSyncTests: XCTestCase {

    // MARK: - Workout summary

    /// A finished workout maps to its started/finished span.
    func testSummaryUsesStartedAndFinishedDates() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = start.addingTimeInterval(3_600)
        let workout = Workout(startedAt: start, finishedAt: end)

        let summary = HealthKitSync.summary(for: workout)

        XCTAssertEqual(summary?.start, start)
        XCTAssertEqual(summary?.end, end)
        XCTAssertEqual(summary?.duration, 3_600)
    }

    /// An in-progress workout (no finish stamp) has nothing to export.
    func testSummaryIsNilWhenUnfinished() {
        let workout = Workout(startedAt: Date(timeIntervalSince1970: 1_000), finishedAt: nil)

        XCTAssertNil(HealthKitSync.summary(for: workout))
    }

    /// Without a `startedAt`, the calendar `date` stands in as the start.
    func testSummaryFallsBackToDateWhenStartMissing() {
        let date = Date(timeIntervalSince1970: 5_000)
        let end = date.addingTimeInterval(1_800)
        let workout = Workout(date: date, startedAt: nil, finishedAt: end)

        let summary = HealthKitSync.summary(for: workout)

        XCTAssertEqual(summary?.start, date)
        XCTAssertEqual(summary?.duration, 1_800)
    }

    /// A finish time earlier than the start is clamped so duration never goes
    /// negative.
    func testSummaryClampsNegativeDuration() {
        let start = Date(timeIntervalSince1970: 10_000)
        let end = start.addingTimeInterval(-500)
        let workout = Workout(startedAt: start, finishedAt: end)

        let summary = HealthKitSync.summary(for: workout)

        XCTAssertEqual(summary?.start, start)
        XCTAssertEqual(summary?.end, start)
        XCTAssertEqual(summary?.duration, 0)
    }

    // MARK: - Bodyweight import

    /// With no measurements on file, a sample is always worth importing.
    func testShouldImportWhenNoMeasurements() {
        XCTAssertTrue(
            HealthKitSync.shouldImport(bodyMassDate: .now, existing: [])
        )
    }

    /// A weight already recorded on the same day blocks a duplicate import.
    func testShouldNotImportWhenSameDayWeightExists() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let existing = [BodyMeasurement(date: day, weight: 180)]

        XCTAssertFalse(
            HealthKitSync.shouldImport(bodyMassDate: day, existing: existing)
        )
    }

    /// A same-day entry that records no weight (e.g. circumferences only) does
    /// not block the bodyweight import.
    func testShouldImportWhenSameDayEntryHasNoWeight() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let existing = [BodyMeasurement(date: day, weight: nil, waist: 33)]

        XCTAssertTrue(
            HealthKitSync.shouldImport(bodyMassDate: day, existing: existing)
        )
    }

    /// A weight recorded on a different day doesn't block today's import.
    func testShouldImportWhenWeightIsFromAnotherDay() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = today.addingTimeInterval(-86_400)
        let existing = [BodyMeasurement(date: yesterday, weight: 180)]

        XCTAssertTrue(
            HealthKitSync.shouldImport(bodyMassDate: today, existing: existing)
        )
    }
}
