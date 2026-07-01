import SwiftUI

/// Placeholder for the workout-logging surface. Real content lands in ba-32q.3+.
struct WorkoutsView: View {
    var body: some View {
        ContentUnavailableView(
            "No Workouts Yet",
            systemImage: "dumbbell",
            description: Text("Logged workouts will appear here.")
        )
        .navigationTitle("Workouts")
    }
}

#Preview {
    NavigationStack {
        WorkoutsView()
    }
}
