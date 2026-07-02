import SwiftData
import SwiftUI

/// The Routines tab: lists saved workout templates and hosts create/edit/delete.
///
/// Tapping a routine's summary opens the editor for that routine; the `+`
/// toolbar button opens the editor for a new one. Both are presented modally so
/// the editor's `Cancel`/`Save` semantics are consistent. Swipe-to-delete
/// removes a routine (its items cascade away with it).
///
/// Each row carries a prominent **Start** button (backed by a matching leading
/// swipe action and context-menu item) that **starts a workout** from the
/// routine: it builds a pre-populated in-progress `Workout` and presents
/// ``ActiveWorkoutView`` for logging — the tie-in between saved templates and
/// the core logging loop (ba-32q.8). The visible button keeps that entry point
/// discoverable rather than hidden behind a swipe/long-press (ba-07l.13).
struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]

    @State private var activeSheet: ActiveSheet?

    /// The workout currently presented full-screen for logging, if any.
    @State private var activeWorkout: Workout?

    var body: some View {
        List {
            ForEach(routines) { routine in
                HStack {
                    Button {
                        activeSheet = .edit(routine)
                    } label: {
                        RoutineRow(routine: routine)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 12)

                    Button {
                        start(routine)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    // An explicit button style keeps this an independent tap
                    // target: without one the enclosing List row would treat
                    // the whole cell as a single button.
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
                    .accessibilityHint("Starts a workout from this routine")
                }
                .swipeActions(edge: .leading) {
                    Button {
                        start(routine)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .tint(.green)
                }
                .contextMenu {
                    Button {
                        start(routine)
                    } label: {
                        Label("Start Workout", systemImage: "play.fill")
                    }
                    Button {
                        activeSheet = .edit(routine)
                    } label: {
                        Label("Edit Routine", systemImage: "pencil")
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Routines")
        .overlay {
            if routines.isEmpty {
                emptyState
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    activeSheet = .new
                } label: {
                    Label("Add Routine", systemImage: "plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .new:
                    RoutineEditorView()
                case .edit(let routine):
                    RoutineEditorView(routine: routine)
                }
            }
        }
        .fullScreenCover(item: $activeWorkout) { workout in
            ActiveWorkoutView(workout: workout)
        }
    }

    /// Builds a pre-populated workout from the routine and opens it for logging.
    private func start(_ routine: Routine) {
        let workout = Workout.from(routine: routine)
        modelContext.insert(workout)
        activeWorkout = workout
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routines[index])
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Routines Yet",
            systemImage: "list.bullet.rectangle",
            description: Text("Tap + to create a workout routine.")
        )
    }

    /// Which editor sheet is showing. `edit` carries the target routine; its
    /// `id` keys the sheet so switching between routines re-presents correctly.
    private enum ActiveSheet: Identifiable {
        case new
        case edit(Routine)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let routine): return routine.id.uuidString
            }
        }
    }
}

/// A single routine row: name plus a summary of its exercise and set counts.
private struct RoutineRow: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(routine.name)
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        let items = routine.items
        let exerciseCount = items.count
        guard exerciseCount > 0 else { return "No exercises" }
        let setCount = items.reduce(0) { $0 + $1.sets.count }
        let exerciseText = "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"
        let setText = "\(setCount) set\(setCount == 1 ? "" : "s")"
        return "\(exerciseText) · \(setText)"
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    ExerciseLibrary.seedIfNeeded(in: container.mainContext)
    return NavigationStack {
        RoutinesView()
    }
    .modelContainer(container)
}
