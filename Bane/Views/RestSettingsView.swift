import SwiftUI

/// Shared keys and defaults for rest-timer preferences, so the settings screen,
/// the active workout, and previews all agree on the storage contract.
enum RestPreferences {
    static let defaultSecondsKey = "restDefaultSeconds"
    static let autoStartKey = "restAutoStart"

    /// The out-of-box rest length before the user customises it.
    static let fallbackSeconds = 90
}

/// Rest-timer preferences: the app-wide default duration used when an exercise
/// has no override, and whether completing a set auto-starts the countdown.
///
/// Presented as a sheet from the Workouts tab.
struct RestSettingsView: View {
    @AppStorage(RestPreferences.defaultSecondsKey)
    private var defaultSeconds = RestPreferences.fallbackSeconds
    @AppStorage(RestPreferences.autoStartKey)
    private var autoStart = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Auto-start after each set", isOn: $autoStart)
                } footer: {
                    Text("When on, checking a set complete starts the rest countdown automatically.")
                }

                Section {
                    Picker("Duration", selection: $defaultSeconds) {
                        ForEach(RestDurations.presets, id: \.self) { seconds in
                            Text(RestDurations.label(seconds)).tag(seconds)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Default rest")
                } footer: {
                    Text("Used for exercises without their own rest override.")
                }
            }
            .navigationTitle("Rest Timer")
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
    RestSettingsView()
}
