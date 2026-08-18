import SwiftUI

/// The "More" tab: a list of secondary sections that don't fit in the design
/// system's 5-slot ``BaneTabGlyph`` bar (Train/Lifts/Plans/Records/More).
///
/// Mirrors the App Store HIG pattern for apps with more than five top-level
/// sections — the primary four keep dedicated tabs, everything else lives
/// one tap deeper behind "More" rather than crowding the bar itself.
struct MoreView: View {
    @Environment(\.banePalette) private var palette

    var body: some View {
        List {
            NavigationLink {
                ChartsView()
            } label: {
                Label("Charts", systemImage: "chart.xyaxis.line")
            }
            NavigationLink {
                MuscleHeatMapView()
            } label: {
                Label("Muscles", systemImage: "flame")
            }
            NavigationLink {
                CalendarView()
            } label: {
                Label("Calendar", systemImage: "calendar")
            }
            NavigationLink {
                AchievementsView()
            } label: {
                Label("Achievements", systemImage: "rosette")
            }
            NavigationLink {
                MeasurementsView()
            } label: {
                Label("Body", systemImage: "ruler")
            }
            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .listRowBackground(palette.surface)
        .listRowSeparatorTint(palette.line)
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .navigationTitle("More")
    }
}

#Preview {
    NavigationStack {
        MoreView()
    }
    .modelContainer(Persistence.inMemoryContainer())
}
