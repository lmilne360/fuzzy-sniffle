import SwiftData
import SwiftUI

/// Application entry point using the SwiftUI app lifecycle.
@main
struct BaneApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Persistence.shared)
    }
}
