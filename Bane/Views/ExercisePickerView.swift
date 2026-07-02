import SwiftData
import SwiftUI

/// Presents the exercise library so the user can pick one to add to the active
/// workout.
///
/// Mirrors ``ExercisesView``'s grouping and live search, but each row is a tap
/// target that hands the chosen `Exercise` back through `onSelect` and dismisses.
struct ExercisePickerView: View {
    /// Called with the exercise the user tapped, immediately before dismissal.
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""

    var body: some View {
        List {
            ForEach(sectionedCategories) { category in
                Section(category.displayName) {
                    ForEach(exercises(in: category)) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            ExercisePickerRow(exercise: exercise)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search exercises")
        .overlay {
            if filteredExercises.isEmpty {
                emptyState
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    /// Exercises matching the current search text (name, category, muscle, or
    /// equipment). Empty search returns everything.
    private var filteredExercises: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return exercises }
        return exercises.filter { exercise in
            exercise.name.localizedCaseInsensitiveContains(query)
                || exercise.category.displayName.localizedCaseInsensitiveContains(query)
                || exercise.primaryMuscle.displayName.localizedCaseInsensitiveContains(query)
                || exercise.equipment.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    /// Categories that currently have at least one matching exercise, in the
    /// enum's declared order.
    private var sectionedCategories: [ExerciseCategory] {
        let present = Set(filteredExercises.map(\.category))
        return ExerciseCategory.allCases.filter { present.contains($0) }
    }

    private func exercises(in category: ExerciseCategory) -> [Exercise] {
        filteredExercises.filter { $0.category == category }
    }

    @ViewBuilder
    private var emptyState: some View {
        if searchText.isEmpty {
            ContentUnavailableView(
                "No Exercises",
                systemImage: "figure.strengthtraining.traditional",
                description: Text("Add exercises from the Exercises tab first.")
            )
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}

/// A single tappable row in the picker: name plus a muscle/equipment subtitle.
private struct ExercisePickerRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
                .foregroundStyle(.primary)
            Text("\(exercise.primaryMuscle.displayName) · \(exercise.equipment.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    ExerciseLibrary.seedIfNeeded(in: container.mainContext)
    return NavigationStack {
        ExercisePickerView { _ in }
    }
    .modelContainer(container)
}
