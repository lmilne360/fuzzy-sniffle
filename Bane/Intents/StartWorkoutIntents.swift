import AppIntents
import Foundation
import SwiftData

/// Starts a new empty workout and opens it for logging.
///
/// Mirrors the "Start Workout" toolbar action in ``WorkoutsView``: creates a
/// blank in-progress `Workout`, persists it, and hands it to the
/// ``WorkoutSessionCoordinator`` so the UI presents ``ActiveWorkoutView``.
struct StartEmptyWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Empty Workout"
    static var description = IntentDescription(
        "Starts a new blank workout, ready to log sets, reps, and weight."
    )

    /// Bring the app to the foreground so the workout is presented for logging.
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = Persistence.shared.mainContext
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        try context.save()

        WorkoutSessionCoordinator.shared.open(workout)
        return .result()
    }
}

/// Starts a workout from one of the user's saved routines and opens it for
/// logging.
///
/// Mirrors the "Start Workout" action in ``RoutinesView``: builds a
/// pre-populated `Workout` from the chosen routine (see
/// `Workout.fromProgressive(routine:in:)`, which applies double-progression
/// targets when the routine opts in), persists it, and hands it to the
/// ``WorkoutSessionCoordinator``.
struct StartRoutineIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Routine"
    static var description = IntentDescription(
        "Starts a workout from one of your saved routines, pre-filled with its target sets."
    )

    static var openAppWhenRun = true

    @Parameter(title: "Routine")
    var routine: RoutineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$routine)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = Persistence.shared.mainContext
        let targetID = routine.id
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate { $0.id == targetID }
        )
        guard let model = try context.fetch(descriptor).first else {
            throw StartRoutineError.routineNotFound
        }

        let workout = Workout.fromProgressive(routine: model, in: context)
        context.insert(workout)
        try context.save()

        WorkoutSessionCoordinator.shared.open(workout)
        return .result()
    }
}

/// Errors surfaced to Siri/Shortcuts when a routine-based start cannot proceed.
enum StartRoutineError: Error, CustomLocalizedStringResourceConvertible {
    /// The selected routine no longer exists (e.g. deleted after the shortcut
    /// was configured).
    case routineNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .routineNotFound:
            return "That routine no longer exists."
        }
    }
}
