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
/// Rest is tied to the workout session, not the view that started it — see
/// ``RestTimerRegistry``, which keeps one instance alive per workout so
/// minimizing and reopening `ActiveWorkoutView` doesn't tear a running rest
/// down. The app never runs two rests at once, so a single pending
/// notification identifier is reused.
@MainActor
@Observable
final class RestTimerController {
    /// Name of the exercise the current rest belongs to, for display. `nil`
    /// when idle.
    private(set) var exerciseName: String?
    /// The `WorkoutExercise` the current rest belongs to, for advancing focus
    /// on completion. `nil` when idle.
    ///
    /// Stored as data — rather than only baked into ``onComplete`` — because
    /// this controller outlives any single `ActiveWorkoutView` instance (see
    /// ``RestTimerRegistry``): a closure captured once at `start(...)` time
    /// would go stale if the view is minimized and a fresh instance takes its
    /// place before the rest completes. The owning view re-derives
    /// `onComplete` from this id against its *current* self whenever it
    /// reappears, instead of relying on a closure captured by a view instance
    /// that may no longer exist.
    private(set) var exerciseID: UUID?
    /// The full planned length of the current rest, in seconds — grows with
    /// each `extend(by:)` so progress stays proportional.
    private(set) var totalSeconds: Int = 0
    /// Absolute time the rest is scheduled to end. `nil` while idle or paused.
    private(set) var endsAt: Date?

    /// `true` while a rest is counting down (or sitting at zero awaiting
    /// dismissal). `false` while paused — nothing is counting, so there's
    /// nothing to show.
    var isRunning: Bool { endsAt != nil }

    /// Guards the one-shot completion routine so it fires exactly once per rest,
    /// however it's reached (natural expiry, `extend` crossing zero, or `skip`).
    private var hasSignalledCompletion = false

    /// Remaining seconds captured at the moment of ``pause(at:)``; `nil` when
    /// not paused. Restores the countdown on ``resume(at:)``.
    private var pausedRemaining: Int?

    /// Invoked once whenever a rest completes, by whichever path got it there.
    /// `ActiveWorkoutView` uses this to advance keyboard focus to the next set.
    var onComplete: (() -> Void)?

    /// Begins a fresh rest of `seconds`, replacing any rest already running.
    func start(seconds: Int, exerciseName: String?, exerciseID: UUID?) {
        guard seconds > 0 else { return }
        totalSeconds = seconds
        self.exerciseName = exerciseName
        self.exerciseID = exerciseID
        endsAt = Date(timeIntervalSinceNow: TimeInterval(seconds))
        hasSignalledCompletion = false
        pausedRemaining = nil
        RestNotifications.schedule(after: TimeInterval(seconds), exerciseName: exerciseName)
    }

    /// Adds (or subtracts) time from the running rest. Also revives a rest
    /// that already hit zero when `seconds` is positive.
    ///
    /// The new end is floored at "now" — a negative adjustment can never push
    /// the countdown below zero — and crossing zero here runs the same
    /// completion routine a natural expiry would, immediately, rather than
    /// leaving the display sitting at zero until the next tick.
    func extend(by seconds: Int) {
        guard let currentEnd = endsAt else { return }
        let now = Date()
        let flooredEnd = max(now, currentEnd.addingTimeInterval(TimeInterval(seconds)))
        endsAt = flooredEnd
        totalSeconds = max(0, totalSeconds + seconds)
        if flooredEnd <= now {
            signalCompletion()
        } else {
            hasSignalledCompletion = false
            RestNotifications.schedule(after: flooredEnd.timeIntervalSinceNow, exerciseName: exerciseName)
        }
    }

    /// Skips the rest early: runs the completion routine (haptic, notification
    /// cancel, focus advance) immediately, then dismisses the countdown.
    func skip() {
        guard endsAt != nil else { return }
        signalCompletion()
        stop()
    }

    /// Ends the rest immediately and silently — used to dismiss a completed
    /// rest, or to cancel one outright (workout finished/discarded, or a set
    /// un-completed) without running the completion routine.
    func stop() {
        endsAt = nil
        exerciseName = nil
        exerciseID = nil
        totalSeconds = 0
        hasSignalledCompletion = false
        pausedRemaining = nil
        onComplete = nil
        RestNotifications.cancel()
    }

    /// Freezes the countdown: the notification is cancelled and the remaining
    /// time captured so ``resume(at:)`` can restore it exactly. No-op while idle.
    func pause(at date: Date) {
        guard endsAt != nil else { return }
        pausedRemaining = remaining(at: date)
        endsAt = nil
        RestNotifications.cancel()
    }

    /// Restores a countdown frozen by ``pause(at:)``, resuming from exactly
    /// where it left off. No-op if not paused, or if it had already reached
    /// zero before the pause.
    func resume(at date: Date) {
        guard let pausedRemaining else { return }
        self.pausedRemaining = nil
        guard pausedRemaining > 0 else { return }
        endsAt = date.addingTimeInterval(TimeInterval(pausedRemaining))
        hasSignalledCompletion = false
        RestNotifications.schedule(after: TimeInterval(pausedRemaining), exerciseName: exerciseName)
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

    /// Called on each UI tick; runs the completion routine once as the rest
    /// naturally reaches zero.
    func tick(_ date: Date) {
        guard endsAt != nil, !hasSignalledCompletion, remaining(at: date) == 0 else { return }
        signalCompletion()
    }

    /// The single completion routine, run exactly once per rest regardless of
    /// which path (natural expiry, `extend` crossing zero, `skip`) triggers it:
    /// cancel the now-redundant notification, fire the haptic, and let the
    /// view advance focus to the next set.
    private func signalCompletion() {
        guard !hasSignalledCompletion else { return }
        hasSignalledCompletion = true
        RestNotifications.cancel()
        Self.playCompletionHaptic()
        onComplete?()
    }

    private static func playCompletionHaptic() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

/// Keeps one ``RestTimerController`` alive per workout for the process's
/// lifetime, so minimizing `ActiveWorkoutView` (which recreates its `@State`
/// from scratch each time it's presented) doesn't tear down a running rest —
/// rest is tied to the workout session, not the view.
@MainActor
final class RestTimerRegistry {
    static let shared = RestTimerRegistry()

    private var controllers: [UUID: RestTimerController] = [:]

    private init() {}

    /// The controller for `workoutID`, creating one on first access.
    func controller(for workoutID: UUID) -> RestTimerController {
        if let existing = controllers[workoutID] { return existing }
        let controller = RestTimerController()
        controllers[workoutID] = controller
        return controller
    }

    /// Drops the controller once its workout is finished or discarded, so it
    /// doesn't leak for the remaining life of the process.
    func remove(_ workoutID: UUID) {
        controllers.removeValue(forKey: workoutID)
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
