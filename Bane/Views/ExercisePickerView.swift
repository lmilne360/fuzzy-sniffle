import SwiftData
import SwiftUI

/// A modal picker for choosing an exercise from the library.
///
/// Mirrors ``ExercisesView``'s grouped, searchable browsing but is
/// selection-oriented: tapping a row invokes ``onSelect`` and dismisses. The
/// caller owns what happens with the chosen exercise — appending a
/// `WorkoutExercise` to an active workout, a `RoutineItem` to a routine, etc.
struct ExercisePickerView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    /// Invoked with the exercise the user tapped, just before dismissal.
    let onSelect: (Exercise) -> Void

    var body: some View {
        List {
            ForEach(sectionedCategories) { category in
                Section(category.displayName) {
                    ForEach(exercises(in: category)) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            row(for: exercise)
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

    private func row(for exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
            Text("\(exercise.primaryMuscle.displayName) · \(exercise.equipment.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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

#Preview {
    let container = Persistence.inMemoryContainer()
    ExerciseLibrary.seedIfNeeded(in: container.mainContext)
    return NavigationStack {
        ExercisePickerView { _ in }
    }
    .modelContainer(container)
}
