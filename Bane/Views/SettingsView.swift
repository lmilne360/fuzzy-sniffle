import SwiftUI

/// The Settings screen, reachable from the More tab.
///
/// Central home for app-wide preferences. Hosts the weight-unit toggle (ba-w6o)
/// and the opt-in workout reminders (ba-oy0.2) alongside the existing rest-timer,
/// iCloud-sync, and data-export screens, which are also reachable from the
/// Workouts tab toolbar.
struct SettingsView: View {
    /// The unit weights are displayed and entered in everywhere; storage stays
    /// pounds. Changing this re-renders every weight surface live.
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback

    // Opt-in workout reminders. Global (not per-routine) UserDefaults-backed
    // state; changing any of these reschedules the local notifications.
    @AppStorage(ReminderPreferences.enabledKey)
    private var reminderEnabled = ReminderPreferences.fallbackEnabled
    @AppStorage(ReminderPreferences.hourKey)
    private var reminderHour = ReminderPreferences.fallbackHour
    @AppStorage(ReminderPreferences.minuteKey)
    private var reminderMinute = ReminderPreferences.fallbackMinute
    @AppStorage(ReminderPreferences.weekdaysKey)
    private var reminderWeekdays = ReminderPreferences.fallbackWeekdays

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

            remindersSection

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

    /// Opt-in workout reminders: an enable toggle that, once on, reveals a time
    /// picker and a day-of-week selector. Every control reschedules the pending
    /// notifications on change; enabling also triggers the shared permission
    /// prompt via the existing `RestNotifications` flow.
    private var remindersSection: some View {
        Section {
            Toggle("Workout reminders", isOn: $reminderEnabled)

            if reminderEnabled {
                DatePicker(
                    "Time",
                    selection: reminderTime,
                    displayedComponents: .hourAndMinute
                )
                WeekdaySelector(mask: $reminderWeekdays)
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Get a nudge to work out at the time and on the days you choose.")
        }
        .onChange(of: reminderEnabled) { _, enabled in
            if enabled { RestNotifications.requestAuthorization() }
            syncReminders()
        }
        .onChange(of: reminderHour) { _, _ in syncReminders() }
        .onChange(of: reminderMinute) { _, _ in syncReminders() }
        .onChange(of: reminderWeekdays) { _, _ in syncReminders() }
    }

    /// Reschedules the reminder notifications to match the current preference.
    private func syncReminders() {
        ReminderScheduler.sync(
            enabled: reminderEnabled,
            hour: reminderHour,
            minute: reminderMinute,
            weekdayMask: reminderWeekdays
        )
    }

    /// Bridges the hour/minute stored in `UserDefaults` to the `Date` a
    /// `DatePicker` binds to, reading and writing only the time-of-day fields.
    private var reminderTime: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = components.hour ?? reminderHour
                reminderMinute = components.minute ?? reminderMinute
            }
        )
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

/// A compact row of seven toggle chips (S M T W T F S) for choosing which days
/// reminders fire, editing the packed `Weekday` mask in place.
private struct WeekdaySelector: View {
    @Binding var mask: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                let isSelected = mask & day.bit != 0
                Button {
                    if isSelected {
                        mask &= ~day.bit
                    } else {
                        mask |= day.bit
                    }
                } label: {
                    Text(day.shortSymbol)
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            isSelected ? Color.accentColor : Color(.secondarySystemFill),
                            in: Capsule()
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.displayName)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
