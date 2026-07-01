import SwiftUI

/// Placeholder for the routines surface. Real content lands in later beads.
struct RoutinesView: View {
    var body: some View {
        ContentUnavailableView(
            "No Routines Yet",
            systemImage: "list.bullet.rectangle",
            description: Text("Saved routines will appear here.")
        )
        .navigationTitle("Routines")
    }
}

#Preview {
    NavigationStack {
        RoutinesView()
    }
}
