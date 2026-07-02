import Foundation
import SwiftData

/// Central configuration for the app's SwiftData stack.
///
/// Owns the canonical ``schema`` (every `@Model` type must be listed here) and
/// vends `ModelContainer`s: a persistent ``shared`` container for the running
/// app and an in-memory container for previews and tests.
enum Persistence {
    /// The full model schema. Add new `@Model` types here as they are created.
    static let schema = Schema([
        Exercise.self,
        Routine.self,
        RoutineItem.self,
        RoutineSet.self,
        Workout.self,
        WorkoutExercise.self,
        SetEntry.self,
        PersonalRecord.self,
        BodyMeasurement.self,
    ])

    /// The on-disk container used by the live app. Created once, lazily.
    @MainActor
    static let shared: ModelContainer = makeContainer(inMemory: false)

    /// A throwaway in-memory container for SwiftUI previews and unit tests.
    /// Data never touches disk and is discarded when the container deallocates.
    @MainActor
    static func inMemoryContainer() -> ModelContainer {
        makeContainer(inMemory: true)
    }

    @MainActor
    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        // On disk, honour the user's iCloud-sync opt-in (ba-07l.12). In-memory
        // containers (previews/tests) never sync.
        let cloudKitEnabled = !inMemory && SyncPreferences.isEnabled

        if cloudKitEnabled {
            // Try the CloudKit-backed store first, then degrade to a local store
            // if iCloud is unavailable (no account, missing entitlement) so the
            // app still launches with on-device data instead of crashing.
            if let container = try? ModelContainer(
                for: schema,
                configurations: [configuration(inMemory: false, cloudKit: true)]
            ) {
                return container
            }
        }

        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration(inMemory: inMemory, cloudKit: false)]
            )
        } catch {
            // A failure here means the schema is invalid or the store is
            // unreadable/incompatible — both are unrecoverable at launch.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// Builds a `ModelConfiguration`, opting into the CloudKit private database
    /// only when `cloudKit` is `true`. All `@Model` types must be
    /// CloudKit-compatible (no unique constraints, optional relationships,
    /// defaulted attributes) for the CloudKit configuration to be valid.
    @MainActor
    private static func configuration(inMemory: Bool, cloudKit: Bool) -> ModelConfiguration {
        if cloudKit {
            return ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(SyncPreferences.containerIdentifier)
            )
        }
        return ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
    }
}
