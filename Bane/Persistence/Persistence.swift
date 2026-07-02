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
        Workout.self,
        WorkoutExercise.self,
        SetEntry.self,
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
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
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
