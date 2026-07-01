import SwiftUI

/// Root shell of the app: a `TabView` hosting the top-level sections, each
/// wrapped in its own `NavigationStack` so navigation state is scoped per tab.
struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                WorkoutsView()
            }
            .tabItem {
                Label("Workouts", systemImage: "dumbbell")
            }

            NavigationStack {
                RoutinesView()
            }
            .tabItem {
                Label("Routines", systemImage: "list.bullet.rectangle")
            }
        }
    }
}

#Preview {
    RootView()
}
