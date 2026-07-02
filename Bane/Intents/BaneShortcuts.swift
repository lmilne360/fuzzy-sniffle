import AppIntents

/// App Shortcuts Bane offers to Siri and the Shortcuts app automatically, with
/// no user setup. Phrases must include the app name via `\(.applicationName)`.
struct BaneShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartEmptyWorkoutIntent(),
            phrases: [
                "Start a workout in \(.applicationName)",
                "Start an empty workout in \(.applicationName)",
                "Begin a workout in \(.applicationName)",
            ],
            shortTitle: "Start Workout",
            systemImageName: "dumbbell"
        )

        AppShortcut(
            intent: StartRoutineIntent(),
            phrases: [
                "Start a routine in \(.applicationName)",
                "Start \(\.$routine) in \(.applicationName)",
                "Begin \(\.$routine) in \(.applicationName)",
            ],
            shortTitle: "Start Routine",
            systemImageName: "list.bullet.rectangle"
        )
    }
}
