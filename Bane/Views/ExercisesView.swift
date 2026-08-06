import SwiftData
import SwiftUI

/// Browse and search the exercise library, and create custom exercises.
///
/// Exercises are grouped by ``ExerciseCategory`` and filtered live by the
/// search field. The `+` toolbar button presents ``AddExerciseView`` for
/// creating a user-defined exercise.
struct ExercisesView: View {
    @Environment(\.banePalette) private var palette
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var isPresentingAdd = false

    var body: some View {
        List {
            ForEach(sectionedCategories) { category in
                Section(category.displayName) {
                    ForEach(exercises(in: category)) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            ExerciseRow(exercise: exercise)
                        }
                        .listRowBackground(palette.surface)
                    }
                }
            }
        }
        .listRowSeparatorTint(palette.line)
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .navigationTitle("Lifts")
        .searchable(text: $searchText, prompt: "Search lifts")
        .overlay {
            if filteredExercises.isEmpty {
                emptyState
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingAdd = true
                } label: {
                    Label("Add Lift", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAdd) {
            NavigationStack {
                AddExerciseView()
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
                "No Lifts",
                systemImage: "figure.strengthtraining.traditional",
                description: Text("Add a custom lift with the + button.")
            )
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}

/// A single row in the exercise list: name plus a muscle/equipment subtitle and
/// a badge for user-created entries.
private struct ExerciseRow: View {
    let exercise: Exercise

    @Environment(\.banePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(exercise.name)
                    .font(BaneFont.body(15))
                    .foregroundStyle(palette.text)
                if exercise.isCustom {
                    BaneBadge(text: "Custom", kind: .accent)
                }
            }
            Text("\(exercise.primaryMuscle.displayName) · \(exercise.equipment.displayName)")
                .font(BaneFont.mono(11))
                .foregroundStyle(palette.text3)
        }
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    ExerciseLibrary.seedIfNeeded(in: container.mainContext)
    return NavigationStack {
        ExercisesView()
    }
    .modelContainer(container)
}
