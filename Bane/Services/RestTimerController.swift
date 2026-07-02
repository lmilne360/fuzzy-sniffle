import Foundation
import Observation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

/// Drives the between-sets rest countdown for a single active workout.
///
/// A rest is started automatically when a set is checked complete (see
/// `ActiveWorkoutView`). The controller tracks an absolute `endsAt` so the
/// countdown stays accurate across UI ticks and app suspension, exposes
/// skip/extend controls, and fires a haptic (foreground) plus a local
/// notification (works while backgrounded/locked) when the interval elapses.
///
/// One instance lives per `ActiveWorkoutView`; the app never runs two rests at
/// once, so a single pending notification identifier is reused.
@MainActor
@Observable
final class RestTimerController {
    /// Name of the exercise the current rest belongs to, for display. `nil`
    /// when idle.
    private(set) var exerciseName: String?
    /// The full planned length of the current rest, in seconds — grows with
    /// each `extend(by:)` so progress stays proportional.
    private(set) var totalSeconds: Int = 0
    /// Absolute time the rest is scheduled to end. `nil` while idle.
    private(set) var endsAt: Date?

    /// `true` while a rest is counting down (or sitting at zero awaiting
    /// dismissal).
    var isRunning: Bool { endsAt != nil }

    /// Guards the one-shot completion haptic so it fires exactly once per rest.
    private var hasSignalledCompletion = false

    /// Begins a fresh rest of `seconds`, replacing any rest already running.
    func start(seconds: Int, exerciseName: String?) {
        guard seconds > 0 else { return }
        totalSeconds = seconds
        self.exerciseName = exerciseName
        endsAt = Date(timeIntervalSinceNow: TimeInterval(seconds))
        hasSignalledCompletion = false
        RestNotifications.schedule(after: TimeInterval(seconds), exerciseName: exerciseName)
    }

    /// Adds time to the running rest (also revives a rest that already hit zero).
    func extend(by seconds: Int) {
        guard endsAt != nil else { return }
        let base = max(Date(), endsAt ?? Date())
        let newEnd = base.addingTimeInterval(TimeInterval(seconds))
        endsAt = newEnd
        totalSeconds += seconds
        hasSignalledCompletion = false
        RestNotifications.schedule(after: newEnd.timeIntervalSinceNow, exerciseName: exerciseName)
    }

    /// Ends the rest immediately, whether skipped early or dismissed at zero.
    func stop() {
        endsAt = nil
        exerciseName = nil
        totalSeconds = 0
        hasSignalledCompletion = false
        RestNotifications.cancel()
    }

    /// Seconds left at `date`, never negative.
    func remaining(at date: Date) -> Int {
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSince(date).rounded(.up)))
    }

    /// Fraction of the rest already elapsed at `date`, in `0...1`.
    func progress(at date: Date) -> Double {
        guard totalSeconds > 0 else { return 1 }
        let done = Double(totalSeconds) - (endsAt?.timeIntervalSince(date) ?? 0)
        return min(1, max(0, done / Double(totalSeconds)))
    }

    /// Called on each UI tick; fires the completion haptic once as the rest
    /// reaches zero. The local notification is scheduled up front, so this only
    /// handles the in-app foreground cue.
    func tick(_ date: Date) {
        guard endsAt != nil, !hasSignalledCompletion, remaining(at: date) == 0 else { return }
        hasSignalledCompletion = true
        Self.playCompletionHaptic()
    }

    private static func playCompletionHaptic() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

/// Local-notification plumbing for the rest timer.
///
/// A time-interval trigger keeps firing even when the app is backgrounded or
/// the device is locked — the primary reason to use notifications rather than
/// an in-process timer alone.
enum RestNotifications {
    /// Single reused identifier — only one rest runs at a time.
    private static let identifier = "com.bane.rest-timer"

    /// Requests alert + sound permission. Safe to call repeatedly; the system
    /// only prompts once.
    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// (Re)schedules the completion notification `seconds` from now, cancelling
    /// any previously pending one.
    static func schedule(after seconds: TimeInterval, exerciseName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = exerciseName.map { "Time for your next set of \($0)." }
            ?? "Time for your next set."
        content.sound = .default

        // Triggers require a strictly positive interval.
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    /// Cancels any pending or already-delivered rest notification.
    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
