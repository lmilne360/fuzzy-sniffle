import SwiftUI

/// Shared keys and defaults for rest-timer preferences, so the settings screen,
/// the active workout, and previews all agree on the storage contract.
enum RestPreferences {
    static let defaultSecondsKey = "restDefaultSeconds"
    static let warmupSecondsKey = "restWarmupSeconds"
    static let autoStartKey = "restAutoStart"

    /// The out-of-box working-set rest length before the user customises it.
    static let fallbackSeconds = 90
    /// The out-of-box warm-up rest length — shorter, as warm-ups rest less.
    static let fallbackWarmupSeconds = 60

    /// The rest countdown for a completed set. A per-exercise override wins over
    /// everything; otherwise warm-up sets rest for `warmupDefault` and working
    /// sets for `workingDefault`.
    static func restDuration(
        isWarmup: Bool,
        exerciseOverride: Int?,
        workingDefault: Int,
        warmupDefault: Int
    ) -> Int {
        if let exerciseOverride { return exerciseOverride }
        return isWarmup ? warmupDefault : workingDefault
    }
}

/// Rest-timer preferences: the app-wide default duration used when an exercise
/// has no override, and whether completing a set auto-starts the countdown.
///
/// Presented as a sheet from the Workouts tab.
struct RestSettingsView: View {
    @AppStorage(RestPreferences.defaultSecondsKey)
    private var defaultSeconds = RestPreferences.fallbackSeconds
    @AppStorage(RestPreferences.warmupSecondsKey)
    private var warmupSeconds = RestPreferences.fallbackWarmupSeconds
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
                    Text("Used for working sets on exercises without their own rest override.")
                }

                Section {
                    Picker("Duration", selection: $warmupSeconds) {
                        ForEach(RestDurations.presets, id: \.self) { seconds in
                            Text(RestDurations.label(seconds)).tag(seconds)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Warm-up rest")
                } footer: {
                    Text("Used for warm-up sets without their own rest override.")
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
