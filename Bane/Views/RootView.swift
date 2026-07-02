import SwiftData
import SwiftUI

/// Root shell of the app: a `TabView` hosting the top-level sections, each
/// wrapped in its own `NavigationStack` so navigation state is scoped per tab.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            NavigationStack {
                WorkoutsView()
            }
            .tabItem {
                Label("Workouts", systemImage: "dumbbell")
            }

            NavigationStack {
                ExercisesView()
            }
            .tabItem {
                Label("Exercises", systemImage: "figure.strengthtraining.traditional")
            }

            NavigationStack {
                RoutinesView()
            }
            .tabItem {
                Label("Routines", systemImage: "list.bullet.rectangle")
            }
        }
        .task {
            // Seed the built-in exercise library once, on first launch.
            ExerciseLibrary.seedIfNeeded(in: modelContext)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(Persistence.inMemoryContainer())
}
