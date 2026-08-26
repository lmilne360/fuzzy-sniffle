import SwiftData
import SwiftUI

/// Form for creating a user-defined exercise.
///
/// Inserts a new `Exercise` with `isCustom == true` into the model context and
/// dismisses. Saving is disabled until a non-empty name is entered.
struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Pre-fills the name field — used when created from the exercise
    /// picker's "no results" empty state, seeded with the search text.
    var initialName = ""
    /// Invoked with the newly-inserted exercise right before this view
    /// dismisses itself, so a caller (e.g. ``ExercisePickerView``) can treat
    /// creation the same as selecting an existing exercise.
    var onCreate: ((Exercise) -> Void)?

    @State private var name = ""
    @State private var category: ExerciseCategory = .chest
    @State private var primaryMuscle: Muscle = .chest
    @State private var equipment: Equipment = .barbell

    init(initialName: String = "", onCreate: ((Exercise) -> Void)? = nil) {
        self.initialName = initialName
        self.onCreate = onCreate
        _name = State(initialValue: initialName)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Exercise name", text: $name)
                    .textInputAutocapitalization(.words)
            }

            Section("Details") {
                Picker("Category", selection: $category) {
                    ForEach(ExerciseCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                Picker("Primary Muscle", selection: $primaryMuscle) {
                    ForEach(Muscle.allCases) { muscle in
                        Text(muscle.displayName).tag(muscle)
                    }
                }
                Picker("Equipment", selection: $equipment) {
                    ForEach(Equipment.allCases) { equipment in
                        Text(equipment.displayName).tag(equipment)
                    }
                }
            }
        }
        .navigationTitle("New Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(trimmedName.isEmpty)
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let exercise = Exercise(
            name: trimmedName,
            category: category,
            primaryMuscle: primaryMuscle,
            equipment: equipment,
            isCustom: true
        )
        modelContext.insert(exercise)
        onCreate?(exercise)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AddExerciseView()
    }
    .modelContainer(Persistence.inMemoryContainer())
}
