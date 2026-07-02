import SwiftUI

/// The Settings screen, reachable from the More tab.
///
/// Central home for app-wide preferences. Hosts the weight-unit toggle (ba-w6o)
/// alongside the existing rest-timer, iCloud-sync, and data-export screens, which
/// are also reachable from the Workouts tab toolbar.
struct SettingsView: View {
    /// The unit weights are displayed and entered in everywhere; storage stays
    /// pounds. Changing this re-renders every weight surface live.
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback

    @State private var isShowingRestSettings = false
    @State private var isShowingSyncSettings = false
    @State private var isShowingExport = false

    var body: some View {
        Form {
            Section {
                Picker("Weight unit", selection: $weightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.abbreviation).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Units")
            } footer: {
                Text("Applies to every weight shown or entered. Values are stored in pounds and converted for display.")
            }

            Section("Preferences") {
                Button {
                    isShowingRestSettings = true
                } label: {
                    settingsRow("Rest Timer", systemImage: "timer")
                }
                Button {
                    isShowingSyncSettings = true
                } label: {
                    settingsRow("iCloud Sync", systemImage: "icloud")
                }
                Button {
                    isShowingExport = true
                } label: {
                    settingsRow("Export Data", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $isShowingRestSettings) {
            RestSettingsView()
        }
        .sheet(isPresented: $isShowingSyncSettings) {
            SyncSettingsView()
        }
        .sheet(isPresented: $isShowingExport) {
            DataExportView()
        }
    }

    /// A tappable settings entry: an SF Symbol, a title, and a disclosure chevron
    /// to read as a navigable row within the plain-button styling.
    private func settingsRow(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
