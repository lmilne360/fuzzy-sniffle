import SwiftUI

/// Shared keys, defaults, and the CloudKit container identifier for iCloud sync,
/// so the settings screen and ``Persistence`` agree on the storage contract.
enum SyncPreferences {
    /// `UserDefaults` key backing the iCloud-sync toggle.
    static let isEnabledKey = "iCloudSyncEnabled"

    /// The CloudKit container that backs the private database. Must match the
    /// `com.apple.developer.icloud-container-identifiers` entitlement.
    static let containerIdentifier = "iCloud.com.bane.Bane"

    /// Whether the user has opted in to iCloud sync. Defaults to `false` so a
    /// fresh install stays purely local until the user turns sync on.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: isEnabledKey)
    }
}

/// iCloud sync preferences: a single opt-in toggle that decides whether the
/// SwiftData store is backed by CloudKit so data follows the user across
/// devices (ba-07l.12).
///
/// The SwiftData container is built once at launch, so switching sync on or off
/// takes effect the next time the app starts — the footer says as much. When
/// sync is unavailable (no iCloud account, missing entitlement) the store falls
/// back to local-only rather than failing; see ``Persistence``.
///
/// Presented as a sheet from the Workouts tab, mirroring ``RestSettingsView``.
struct SyncSettingsView: View {
    @AppStorage(SyncPreferences.isEnabledKey) private var syncEnabled = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("iCloud Sync", isOn: $syncEnabled)
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("When on, your workouts, routines, exercises, records, and body measurements sync across your devices through iCloud. Restart the app to apply a change. Requires an iCloud account.")
                }
            }
            .navigationTitle("iCloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SyncSettingsView()
}
