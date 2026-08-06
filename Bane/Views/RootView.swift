import SwiftData
import SwiftUI

/// Root shell of the app: a `TabView` hosting the top-level sections, each
/// wrapped in its own `NavigationStack` so navigation state is scoped per tab.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.banePalette) private var palette

    /// Presents workouts started via Siri/Shortcuts App Intents, which run
    /// outside the view hierarchy and hand off through this coordinator.
    @Bindable private var sessionCoordinator = WorkoutSessionCoordinator.shared

    var body: some View {
        TabView {
            NavigationStack {
                WorkoutsView()
            }
            .tabItem {
                Label {
                    Text("Train")
                } icon: {
                    BaneTabGlyph(kind: .bars)
                }
            }

            NavigationStack {
                ExercisesView()
            }
            .tabItem {
                Label {
                    Text("Lifts")
                } icon: {
                    BaneTabGlyph(kind: .grid)
                }
            }

            NavigationStack {
                RoutinesView()
            }
            .tabItem {
                Label {
                    Text("Plans")
                } icon: {
                    BaneTabGlyph(kind: .list)
                }
            }

            NavigationStack {
                RecordsView()
            }
            .tabItem {
                Label {
                    Text("Records")
                } icon: {
                    BaneTabGlyph(kind: .diamond)
                }
            }

            NavigationStack {
                ChartsView()
            }
            .tabItem {
                Label("Charts", systemImage: "chart.xyaxis.line")
            }

            NavigationStack {
                MuscleHeatMapView()
            }
            .tabItem {
                Label("Muscles", systemImage: "flame")
            }

            NavigationStack {
                CalendarView()
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }

            NavigationStack {
                AchievementsView()
            }
            .tabItem {
                Label("Achievements", systemImage: "rosette")
            }

            NavigationStack {
                MeasurementsView()
            }
            .tabItem {
                Label("Body", systemImage: "ruler")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .toolbarBackground(palette.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
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
