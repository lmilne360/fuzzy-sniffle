import UserNotifications
import XCTest
@testable import Bane

/// Unit tests for the opt-in workout reminders (ba-oy0.2).
///
/// The scheduling logic that maps a preference (enabled / time / chosen days)
/// onto repeating calendar notifications is pure and side-effect-free, so these
/// exercise ``Weekday`` mask packing and ``ReminderScheduler/requests(hour:minute:weekdays:)``
/// directly without touching `UNUserNotificationCenter`.
final class ReminderSchedulerTests: XCTestCase {

    // MARK: - Weekday mask packing

    /// Each weekday matches `Calendar`'s 1-based numbering so components map
    /// straight onto a calendar trigger.
    func testWeekdayRawValuesMatchCalendar() {
        XCTAssertEqual(Weekday.sunday.rawValue, 1)
        XCTAssertEqual(Weekday.saturday.rawValue, 7)
    }

    /// Packing a set of days and unpacking it round-trips to the same days in
    /// calendar order.
    func testMaskRoundTrip() {
        let days: [Weekday] = [.monday, .wednesday, .friday]
        let mask = Weekday.mask(of: days)
        XCTAssertEqual(Weekday.days(fromMask: mask), days)
    }

    /// An empty mask selects no days; a full mask selects all seven in order.
    func testMaskEdgeCases() {
        XCTAssertEqual(Weekday.days(fromMask: 0), [])
        XCTAssertEqual(Weekday.days(fromMask: Weekday.mask(of: Weekday.allCases)), Weekday.allCases)
    }

    /// The out-of-box default is Mon / Wed / Fri.
    func testFallbackWeekdaysAreMonWedFri() {
        XCTAssertEqual(
            Weekday.days(fromMask: ReminderPreferences.fallbackWeekdays),
            [.monday, .wednesday, .friday]
        )
    }

    // MARK: - Request construction

    /// One repeating request is built per selected weekday, each with a stable
    /// per-day identifier.
    func testRequestPerWeekdayWithStableIdentifiers() {
        let weekdays: [Weekday] = [.tuesday, .thursday]
        let requests = ReminderScheduler.requests(hour: 7, minute: 30, weekdays: weekdays)

        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(
            requests.map(\.identifier),
            [ReminderScheduler.identifier(for: .tuesday), ReminderScheduler.identifier(for: .thursday)]
        )
    }

    /// Each request fires at the chosen time on its own weekday and repeats.
    func testTriggerCarriesTimeAndWeekday() throws {
        let requests = ReminderScheduler.requests(hour: 18, minute: 15, weekdays: [.monday])
        let trigger = try XCTUnwrap(requests.first?.trigger as? UNCalendarNotificationTrigger)

        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.weekday, Weekday.monday.rawValue)
        XCTAssertEqual(trigger.dateComponents.hour, 18)
        XCTAssertEqual(trigger.dateComponents.minute, 15)
    }

    /// No selected days means nothing to schedule.
    func testNoWeekdaysProducesNoRequests() {
        XCTAssertTrue(ReminderScheduler.requests(hour: 9, minute: 0, weekdays: []).isEmpty)
    }

    /// The cleanup identifier list covers every weekday so `sync` can clear a
    /// stale schedule regardless of which days were previously chosen.
    func testAllIdentifiersCoverEveryWeekday() {
        XCTAssertEqual(ReminderScheduler.allIdentifiers.count, Weekday.allCases.count)
        XCTAssertEqual(Set(ReminderScheduler.allIdentifiers).count, Weekday.allCases.count)
    }
}
