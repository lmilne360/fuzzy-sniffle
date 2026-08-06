import SwiftData
import SwiftUI

/// Application entry point using the SwiftUI app lifecycle.
@main
struct BaneApp: App {
    @AppStorage(ThemePreferences.themeKey) private var theme = ThemePreferences.fallback

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.banePalette, theme.palette)
                .tint(theme.palette.accent)
                .preferredColorScheme(.dark)
        }
        .modelContainer(Persistence.shared)
    }
}
