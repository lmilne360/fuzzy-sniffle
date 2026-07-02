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
                let sets = item.orderedSets.map {
                    DraftSet(targetReps: $0.targetReps, targetWeight: $0.targetWeight)
                }
                return DraftItem(exercise: exercise, sets: sets)
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
        items.append(DraftItem(exercise: exercise, sets: DraftItem.defaultSets()))
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
            let item = RoutineItem(order: index, exercise: draft.exercise)
            item.routine = target
            modelContext.insert(item)

            for (setIndex, draftSet) in draft.sets.enumerated() {
                let set = RoutineSet(
                    order: setIndex,
                    targetReps: draftSet.targetReps,
                    targetWeight: draftSet.targetWeight
                )
                set.routineItem = item
                modelContext.insert(set)
            }
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
    var sets: [DraftSet]

    /// The sets a freshly-added exercise starts with: three working sets seeded
    /// with a sensible default rep target and no weight yet.
    static func defaultSets() -> [DraftSet] {
        (0..<3).map { _ in DraftSet(targetReps: 10, targetWeight: 0) }
    }
}

/// A mutable, in-memory target set. Keeps its own identity so `ForEach` stays
/// stable as sets are added and removed before saving.
private struct DraftSet: Identifiable {
    let id = UUID()
    var targetReps: Int
    var targetWeight: Double
}

/// One editable exercise row: name/subtitle plus a per-set list of target reps
/// and weight, with controls to add or remove sets.
private struct DraftItemRow: View {
    @Binding var item: DraftItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.exercise.name)
                Text("\(item.exercise.primaryMuscle.displayName) · \(item.exercise.equipment.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if item.sets.isEmpty {
                Text("No sets yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array($item.sets.enumerated()), id: \.element.id) { index, $set in
                    DraftSetRow(number: index + 1, set: $set) {
                        removeSet(at: index)
                    }
                }
            }

            Button {
                addSet()
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    /// Appends a set, copying the last set's targets as a starting point.
    private func addSet() {
        let previous = item.sets.last
        item.sets.append(
            DraftSet(
                targetReps: previous?.targetReps ?? 10,
                targetWeight: previous?.targetWeight ?? 0
            )
        )
    }

    private func removeSet(at index: Int) {
        guard item.sets.indices.contains(index) else { return }
        item.sets.remove(at: index)
    }
}

/// A single editable target set: its number plus reps and weight fields and a
/// remove control.
private struct DraftSetRow: View {
    let number: Int
    @Binding var set: DraftSet
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.15), in: Circle())
                .foregroundStyle(.secondary)

            fieldColumn(title: "Reps") {
                TextField("0", value: $set.targetReps, format: .number)
                    .keyboardType(.numberPad)
            }

            fieldColumn(title: "Weight") {
                TextField("0", value: $set.targetWeight, format: .number)
                    .keyboardType(.decimalPad)
            }

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove set \(number)")
        }
    }

    /// A titled, left-aligned numeric entry column.
    private func fieldColumn(title: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            field()
                .multilineTextAlignment(.leading)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("New") {
    NavigationStack {
        RoutineEditorView()
    }
    .modelContainer(Persistence.inMemoryContainer())
}
