import SwiftData
import SwiftUI

/// Root shell of the app: a `TabView` hosting the top-level sections, each
/// wrapped in its own `NavigationStack` so navigation state is scoped per tab.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    /// Presents workouts started via Siri/Shortcuts App Intents, which run
    /// outside the view hierarchy and hand off through this coordinator.
    @Bindable private var sessionCoordinator = WorkoutSessionCoordinator.shared

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

            NavigationStack {
                RecordsView()
            }
            .tabItem {
                Label("Records", systemImage: "trophy")
            }

            NavigationStack {
                MuscleHeatMapView()
            }
            .tabItem {
                Label("Muscles", systemImage: "flame")
            }

            NavigationStack {
                MeasurementsView()
            }
            .tabItem {
                Label("Body", systemImage: "ruler")
            }
        }
        .task {
            // Seed the built-in exercise library once, on first launch.
            ExerciseLibrary.seedIfNeeded(in: modelContext)
        }
        .fullScreenCover(item: $sessionCoordinator.pendingWorkout) { workout in
            ActiveWorkoutView(workout: workout)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(Persistence.inMemoryContainer())
}
