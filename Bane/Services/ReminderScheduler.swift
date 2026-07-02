import Foundation
import UserNotifications

/// A day of the week, numbered to match `Calendar`'s 1-based weekday values
/// (Sunday = 1 … Saturday = 7) so a `Weekday` maps straight onto the
/// `DateComponents.weekday` a `UNCalendarNotificationTrigger` expects.
enum Weekday: Int, CaseIterable, Identifiable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int { rawValue }

    /// Single-letter label for the compact weekday selector (S M T W T F S).
    var shortSymbol: String {
        switch self {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }

    /// Full day name, used for accessibility labels where the single-letter
    /// symbol would be ambiguous.
    var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    /// The single bit this day occupies in the packed weekday mask.
    var bit: Int { 1 << (rawValue - 1) }

    /// The days selected in a packed mask, in calendar order.
    static func days(fromMask mask: Int) -> [Weekday] {
        allCases.filter { mask & $0.bit != 0 }
    }

    /// Packs a set of days into a single `Int` mask suitable for `UserDefaults`.
    static func mask(of days: some Sequence<Weekday>) -> Int {
        days.reduce(0) { $0 | $1.bit }
    }
}

/// Shared storage contract for the opt-in workout-reminder preference, so the
/// settings screen and the scheduler agree on keys and out-of-box defaults.
///
/// The preference is global (not per-routine) and lives entirely in
/// `UserDefaults` — there is no model change (ba-oy0.2). Reminders are **off**
/// by default, so a fresh install schedules nothing until the user opts in.
enum ReminderPreferences {
    static let enabledKey = "workoutReminderEnabled"
    static let hourKey = "workoutReminderHour"
    static let minuteKey = "workoutReminderMinute"
    static let weekdaysKey = "workoutReminderWeekdays"

    static let fallbackEnabled = false
    /// Default nudge time: 6:00 PM, a common post-work training slot.
    static let fallbackHour = 18
    static let fallbackMinute = 0
    /// Mon / Wed / Fri out of the box — a widely used lifting cadence. Only
    /// takes effect once the user enables reminders.
    static let fallbackWeekdays = Weekday.mask(of: [.monday, .wednesday, .friday])
}

/// Schedules the opt-in workout reminders as repeating local notifications.
///
/// Each selected weekday gets its own repeating `UNCalendarNotificationTrigger`
/// firing at the chosen hour/minute, so the reminders keep arriving across app
/// launches without any background work. Requests carry a stable per-weekday
/// identifier so `sync(...)` can reconcile the schedule by clearing and
/// re-adding, rather than accumulating duplicates.
///
/// Notification permission is **not** requested here — the app reuses the
/// existing `RestNotifications.requestAuthorization()` flow.
enum ReminderScheduler {
    private static let identifierPrefix = "com.bane.workout-reminder."

    /// Stable notification identifier for a given weekday.
    static func identifier(for weekday: Weekday) -> String {
        identifierPrefix + String(weekday.rawValue)
    }

    /// Identifiers for every weekday, whether or not currently scheduled — used
    /// to clear the full set before rescheduling.
    static var allIdentifiers: [String] {
        Weekday.allCases.map(identifier(for:))
    }

    /// Builds one repeating notification request per selected weekday. Pure and
    /// side-effect-free so the scheduling logic can be unit-tested without the
    /// notification center.
    static func requests(hour: Int, minute: Int, weekdays: [Weekday]) -> [UNNotificationRequest] {
        weekdays.map { weekday in
            var components = DateComponents()
            components.weekday = weekday.rawValue
            components.hour = hour
            components.minute = minute

            let content = UNMutableNotificationContent()
            content.title = "Time to train"
            content.body = "Your workout is waiting — let's move."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return UNNotificationRequest(
                identifier: identifier(for: weekday),
                content: content,
                trigger: trigger
            )
        }
    }

    /// Reconciles the scheduled reminders with the current preference: clears
    /// every weekday request, then re-adds them only when reminders are enabled
    /// and at least one day is selected. Safe to call on any preference change.
    static func sync(enabled: Bool, hour: Int, minute: Int, weekdayMask: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)

        guard enabled else { return }
        let weekdays = Weekday.days(fromMask: weekdayMask)
        guard !weekdays.isEmpty else { return }

        for request in requests(hour: hour, minute: minute, weekdays: weekdays) {
            center.add(request)
        }
    }
}
