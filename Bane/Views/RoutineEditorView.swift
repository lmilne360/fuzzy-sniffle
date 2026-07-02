import SwiftData
import SwiftUI

/// Create or edit a workout routine (template).
///
/// The editor works on an in-memory **draft** rather than mutating SwiftData
/// directly, so a `Cancel` discards everything cleanly and a brand-new routine
/// never leaves an orphan behind. Changes are materialized into the store only
/// on `Save`:
/// - **New routine** — a `Routine` is inserted with fresh `RoutineItem`s.
/// - **Existing routine** — the name is updated and its items are rebuilt from
///   the draft (small lists, so a rebuild is simpler and cheaper than diffing).
struct RoutineEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The routine being edited, or `nil` when creating a new one.
    private let routine: Routine?

    @State private var name: String
    @State private var items: [DraftItem]
    @State private var isPresentingPicker = false

    init(routine: Routine? = nil) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _items = State(
            initialValue: (routine?.orderedItems ?? []).compactMap { item in
                // Drop items whose exercise was deleted out from under us; they
                // can't be meaningfully edited or re-saved.
                guard let exercise = item.exercise else { return nil }
                return DraftItem(exercise: exercise, targetSets: item.targetSets)
            }
        )
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEditing: Bool { routine != nil }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Routine name", text: $name)
                    .textInputAutocapitalization(.words)
            }

            Section("Exercises") {
                if items.isEmpty {
                    Text("No exercises yet. Add one below.")
                        .foregroundStyle(.secondary)
                }

                ForEach($items) { $item in
                    DraftItemRow(item: $item)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)

                Button {
                    isPresentingPicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Routine" : "New Routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(trimmedName.isEmpty)
            }
            ToolbarItem(placement: .topBarLeading) {
                if !items.isEmpty {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $isPresentingPicker) {
            NavigationStack {
                ExercisePickerView { exercise in
                    addExercise(exercise)
                }
            }
        }
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        items.move(fromOffsets: offsets, toOffset: destination)
    }

    private func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    private func addExercise(_ exercise: Exercise) {
        items.append(DraftItem(exercise: exercise, targetSets: 3))
    }

    /// Materialize the draft into SwiftData and dismiss.
    private func save() {
        guard !trimmedName.isEmpty else { return }

        let target: Routine
        if let routine {
            target = routine
            target.name = trimmedName
            // Rebuild items: delete the existing ones and recreate from the
            // draft so `order` and membership always match what's on screen.
            for old in target.items {
                modelContext.delete(old)
            }
        } else {
            target = Routine(name: trimmedName)
            modelContext.insert(target)
        }

        for (index, draft) in items.enumerated() {
            let item = RoutineItem(
                order: index,
                targetSets: draft.targetSets,
                exercise: draft.exercise
            )
            item.routine = target
            modelContext.insert(item)
        }

        dismiss()
    }
}

/// A mutable, in-memory line in the editor. Holds a reference to a persisted
/// `Exercise` but keeps its own identity so `ForEach`/`onMove` stay stable as
/// rows are reordered before saving.
private struct DraftItem: Identifiable {
    let id = UUID()
    var exercise: Exercise
    var targetSets: Int
}

/// One editable exercise row: name/subtitle plus a stepper for the target set
/// count.
private struct DraftItemRow: View {
    @Binding var item: DraftItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.exercise.name)
                Text("\(item.exercise.primaryMuscle.displayName) · \(item.exercise.equipment.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Stepper(
                "Target: \(item.targetSets) \(item.targetSets == 1 ? "set" : "sets")",
                value: $item.targetSets,
                in: 1...20
            )
            .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}

#Preview("New") {
    NavigationStack {
        RoutineEditorView()
    }
    .modelContainer(Persistence.inMemoryContainer())
}
