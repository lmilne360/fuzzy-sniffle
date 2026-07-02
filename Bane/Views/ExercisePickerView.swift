import SwiftData
import SwiftUI

/// Suggestion logic for the "swap exercise" flow.
///
/// Extracted from the view so the rule — alternatives share the source's
/// primary muscle, the source itself excluded — is unit-testable without a
/// SwiftUI environment.
enum ExerciseAlternatives {
    /// Exercises from `library` that make sensible swaps for `exercise`: those
    /// training the same primary muscle, with `exercise` itself removed. Order
    /// follows the input (the picker feeds it name-sorted library rows).
    static func suggestions(for exercise: Exercise, in library: [Exercise]) -> [Exercise] {
        library.filter { $0.id != exercise.id && $0.primaryMuscle == exercise.primaryMuscle }
    }
}

/// A modal picker for choosing an exercise from the library.
///
/// Mirrors ``ExercisesView``'s grouped, searchable browsing but is
/// selection-oriented: tapping a row invokes ``onSelect`` and dismisses. The
/// caller owns what happens with the chosen exercise — appending a
/// `WorkoutExercise` to an active workout, a `RoutineItem` to a routine, etc.
///
/// Pass ``alternativesFor`` to run the "swap" variant: a *Suggested
/// Alternatives* section leads with exercises sharing that exercise's primary
/// muscle (the exercise itself excluded everywhere), and the rest of the
/// library follows below.
struct ExercisePickerView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    /// When set, the picker becomes a swap flow keyed on this exercise: its
    /// same-muscle alternatives are surfaced up top and it is filtered out of
    /// the browse list. `nil` for ordinary add-exercise browsing.
    var alternativesFor: Exercise?
    /// Navigation title — `"Swap Exercise"` for the swap flow, the default
    /// otherwise.
    var title = "Add Exercise"

    /// Invoked with the exercise the user tapped, just before dismissal.
    let onSelect: (Exercise) -> Void

    var body: some View {
        List {
            if !suggestedExercises.isEmpty {
                Section("Suggested Alternatives") {
                    ForEach(suggestedExercises) { exercise in
                        selectButton(for: exercise)
                    }
                }
            }
            ForEach(sectionedCategories) { category in
                Section(category.displayName) {
                    ForEach(exercises(in: category)) { exercise in
                        selectButton(for: exercise)
                    }
                }
            }
        }
        .navigationTitle(title)
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

    /// A library row that reports its exercise and dismisses when tapped.
    private func selectButton(for exercise: Exercise) -> some View {
        Button {
            onSelect(exercise)
            dismiss()
        } label: {
            row(for: exercise)
        }
        .buttonStyle(.plain)
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
    /// equipment), with the swap source — if any — filtered out. Empty search
    /// returns the whole (source-less) library.
    private var filteredExercises: [Exercise] {
        let base = alternativesFor.map { source in
            exercises.filter { $0.id != source.id }
        } ?? exercises
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter { exercise in
            exercise.name.localizedCaseInsensitiveContains(query)
                || exercise.category.displayName.localizedCaseInsensitiveContains(query)
                || exercise.primaryMuscle.displayName.localizedCaseInsensitiveContains(query)
                || exercise.equipment.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    /// Same-muscle swap suggestions for the swap flow, respecting the current
    /// search. Empty for ordinary browsing (no ``alternativesFor``).
    private var suggestedExercises: [Exercise] {
        guard let source = alternativesFor else { return [] }
        return ExerciseAlternatives.suggestions(for: source, in: filteredExercises)
    }

    /// Exercises shown in the browse-by-category portion. In the swap flow the
    /// suggested alternatives are lifted into their own leading section, so they
    /// are excluded here to avoid listing them twice.
    private var browseExercises: [Exercise] {
        guard alternativesFor != nil else { return filteredExercises }
        let suggested = Set(suggestedExercises.map(\.id))
        return filteredExercises.filter { !suggested.contains($0.id) }
    }

    /// Categories that currently have at least one matching exercise, in the
    /// enum's declared order.
    private var sectionedCategories: [ExerciseCategory] {
        let present = Set(browseExercises.map(\.category))
        return ExerciseCategory.allCases.filter { present.contains($0) }
    }

    private func exercises(in category: ExerciseCategory) -> [Exercise] {
        browseExercises.filter { $0.category == category }
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
