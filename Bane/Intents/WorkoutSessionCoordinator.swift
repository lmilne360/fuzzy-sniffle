import Foundation
import Observation

/// Bridges App Intents (Siri/Shortcuts) into the SwiftUI navigation layer.
///
/// App Intents run outside the view hierarchy, so they can create a `Workout`
/// but cannot present a view directly. They hand it off here; ``RootView``
/// observes ``pendingWorkout`` and presents ``ActiveWorkoutView`` for it. The
/// binding is cleared automatically when the user dismisses the session.
@MainActor
@Observable
final class WorkoutSessionCoordinator {
    /// Shared instance — App Intents and the UI must agree on one coordinator.
    static let shared = WorkoutSessionCoordinator()

    /// A workout an App Intent has asked the UI to open for logging, if any.
    var pendingWorkout: Workout?

    private init() {}

    /// Requests that the UI present `workout` full-screen for logging.
    func open(_ workout: Workout) {
        pendingWorkout = workout
    }
}
