import Foundation
import SwiftData

/// Central configuration for the app's SwiftData stack.
///
/// Owns the canonical ``schema`` (every `@Model` type must be listed here) and
/// vends `ModelContainer`s: a persistent ``shared`` container for the running
/// app and an in-memory container for previews and tests.
///
/// The persistent container mirrors to CloudKit's private database so a user's
/// data follows them across their devices. CloudKit imposes schema constraints
/// the models satisfy: no `@Attribute(.unique)` constraints, every non-optional
/// attribute has a default value, and every to-one relationship is optional.
/// The in-memory container skips CloudKit entirely — previews and tests must
/// not touch the network or require an iCloud account.
enum Persistence {
    /// The CloudKit container the private database mirrors into. Must match the
    /// `com.apple.developer.icloud-container-identifiers` entitlement.
    static let cloudKitContainerID = "iCloud.com.bane.Bane"

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
        // On-disk stores mirror to the private CloudKit database; in-memory
        // stores (previews, tests) stay local so they need no iCloud account.
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = inMemory
            ? .none
            : .private(cloudKitContainerID)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKitDatabase
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A failure here means the schema is invalid or the store is
            // unreadable/incompatible — both are unrecoverable at launch.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
