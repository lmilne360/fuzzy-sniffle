import SwiftData
import SwiftUI

/// Root shell of the app: a `TabView` hosting the top-level sections, each
/// wrapped in its own `NavigationStack` so navigation state is scoped per tab.
///
/// Matches the design system's 5-slot `TabBar` (Train/Lifts/Plans/Records/More):
/// the app has more sections than that leaves room for, so everything past the
/// four primary ones (Charts, Muscles, Calendar, Achievements, Body, Settings)
/// lives one tap deeper behind ``MoreView``, the design system's intended
/// "More" slot (`dots` glyph) — rather than either cramming a 9-wide bar or
/// hand-rolling a custom non-native tab bar to force a literal 5-button row.
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
                MoreView()
            }
            .tabItem {
                Label {
                    Text("More")
                } icon: {
                    BaneTabGlyph(kind: .dots)
                }
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
