import AppIntents
import Foundation
import SwiftData

/// App Intents representation of a `Routine`, so Siri and Shortcuts can present
/// the user's saved routines as a pickable, spoken-name-matchable parameter.
struct RoutineEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Routine")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = RoutineEntityQuery()
}

/// Resolves `RoutineEntity` values from the app's SwiftData store — by id (when
/// Shortcuts re-hydrates a saved parameter), by spoken name (Siri matching), and
/// as suggestions (the picker list).
struct RoutineEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [RoutineEntity] {
        try fetch { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [RoutineEntity] {
        try fetch().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [RoutineEntity] {
        try fetch()
    }

    /// Fetches routines (newest first) mapped to entities, optionally filtered.
    @MainActor
    private func fetch(
        where isIncluded: (Routine) -> Bool = { _ in true }
    ) throws -> [RoutineEntity] {
        let descriptor = FetchDescriptor<Routine>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try Persistence.shared.mainContext
            .fetch(descriptor)
            .filter(isIncluded)
            .map { RoutineEntity(id: $0.id, name: $0.name) }
    }
}
