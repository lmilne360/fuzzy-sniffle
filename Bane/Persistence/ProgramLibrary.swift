import Foundation
import SwiftData

/// A small catalog of ready-made training programs and the logic to turn one
/// into `Routine`s with a single tap (ba-oy0.5).
///
/// Programs are plain, allocation-free data — they carry no `@Model` of their
/// own. Instantiating a program materializes its workouts into the *existing*
/// `Routine` / `RoutineItem` / `RoutineSet` models, referencing the exercises
/// already seeded by ``ExerciseLibrary``. That keeps the schema untouched: a
/// created program routine is indistinguishable from a hand-built one and can
/// be edited, started, or deleted like any other.
enum ProgramLibrary {
    /// One planned exercise within a program workout: which exercise (matched by
    /// name against the seeded library) and how many sets of how many reps.
    ///
    /// Weight is intentionally left for the user to fill in — a canned program
    /// can't know anyone's working loads — so instantiation seeds every set at
    /// `0` lb, exactly like a freshly-added exercise in the routine editor.
    struct ExercisePlan {
        /// Must match a name in ``ExerciseLibrary/catalog`` (case-insensitively);
        /// an unmatched name is skipped at instantiation rather than fabricated.
        let exerciseName: String
        let setCount: Int
        let targetReps: Int
    }

    /// One workout in a program. Each workout instantiates into its own
    /// `Routine`, so a 3-day split produces three routines.
    struct WorkoutPlan {
        /// Becomes the created `Routine`'s name.
        let name: String
        let exercises: [ExercisePlan]
    }

    /// A ready-made program: a titled, described bundle of one or more workouts.
    struct Program: Identifiable {
        /// Stable slug, handy for `ForEach` identity and analytics.
        let id: String
        let name: String
        /// One-line summary shown in the browse list.
        let tagline: String
        /// Longer description shown on the detail screen.
        let overview: String
        let workouts: [WorkoutPlan]

        /// How many routines instantiating this program will create.
        var routineCount: Int { workouts.count }
    }

    /// The built-in programs, in display order.
    static let catalog: [Program] = [
        strongLifts5x5,
        pushPullLegs,
        fullBodyBeginner,
    ]

    /// Instantiate every workout in `program` as a `Routine` in `context`.
    ///
    /// Exercises are resolved by name against the exercises already in the
    /// store (the seeded library). An unrecognized name is skipped — the program
    /// never fabricates a new `Exercise` — so a routine only ever references real
    /// library entries. Returns the routines that were created, in program order.
    ///
    /// Caller is responsible for saving the context if durability is needed
    /// before the next autosave, mirroring how ``RoutineEditorView`` defers to
    /// SwiftData's own save cadence.
    @MainActor
    @discardableResult
    static func instantiate(_ program: Program, in context: ModelContext) -> [Routine] {
        // Build a case-insensitive name → Exercise index once, keeping the first
        // match for any duplicate names.
        let library = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var byName: [String: Exercise] = [:]
        for exercise in library {
            let key = exercise.name.lowercased()
            if byName[key] == nil { byName[key] = exercise }
        }

        var created: [Routine] = []
        for workout in program.workouts {
            let routine = Routine(name: workout.name)
            context.insert(routine)

            // `order` advances only for exercises we could actually resolve, so a
            // skipped (unknown) exercise leaves no gap in the ordering.
            var order = 0
            for plan in workout.exercises {
                guard let exercise = byName[plan.exerciseName.lowercased()] else { continue }
                let item = RoutineItem(order: order, exercise: exercise)
                item.routine = routine
                context.insert(item)

                for setIndex in 0..<max(0, plan.setCount) {
                    let set = RoutineSet(order: setIndex, targetReps: plan.targetReps, targetWeight: 0)
                    set.routineItem = item
                    context.insert(set)
                }
                order += 1
            }
            created.append(routine)
        }
        return created
    }

    // MARK: - Program definitions

    /// StrongLifts 5×5: the classic two-workout (A/B) linear-progression barbell
    /// program. Alternate A and B each session; add weight every time.
    private static let strongLifts5x5 = Program(
        id: "stronglifts-5x5",
        name: "StrongLifts 5×5",
        tagline: "Two alternating full-body barbell days · 5 sets of 5",
        overview: """
        A simple, proven strength program built on five compound barbell lifts. \
        Run Workout A and Workout B on alternating training days (three sessions \
        a week), and add a little weight to the bar every session.

        Squats appear in both workouts; the deadlift is a single heavy set of \
        five. Fill in your starting weights when you begin.
        """,
        workouts: [
            WorkoutPlan(name: "StrongLifts 5×5 · Workout A", exercises: [
                ExercisePlan(exerciseName: "Back Squat", setCount: 5, targetReps: 5),
                ExercisePlan(exerciseName: "Barbell Bench Press", setCount: 5, targetReps: 5),
                ExercisePlan(exerciseName: "Barbell Row", setCount: 5, targetReps: 5),
            ]),
            WorkoutPlan(name: "StrongLifts 5×5 · Workout B", exercises: [
                ExercisePlan(exerciseName: "Back Squat", setCount: 5, targetReps: 5),
                ExercisePlan(exerciseName: "Overhead Press", setCount: 5, targetReps: 5),
                ExercisePlan(exerciseName: "Conventional Deadlift", setCount: 1, targetReps: 5),
            ]),
        ]
    )

    /// Push / Pull / Legs: a popular three-day hypertrophy split rotating pressing
    /// muscles, pulling muscles, and the lower body.
    private static let pushPullLegs = Program(
        id: "push-pull-legs",
        name: "Push / Pull / Legs",
        tagline: "Three-day hypertrophy split · chest & shoulders, back & arms, legs",
        overview: """
        A balanced three-day split that groups the body by movement pattern: \
        pushing muscles (chest, shoulders, triceps), pulling muscles (back, \
        biceps), and the legs. Run it three or six days a week depending on your \
        recovery, aiming for moderate reps and steady weekly progression.
        """,
        workouts: [
            WorkoutPlan(name: "PPL · Push", exercises: [
                ExercisePlan(exerciseName: "Barbell Bench Press", setCount: 4, targetReps: 8),
                ExercisePlan(exerciseName: "Overhead Press", setCount: 3, targetReps: 10),
                ExercisePlan(exerciseName: "Incline Dumbbell Press", setCount: 3, targetReps: 10),
                ExercisePlan(exerciseName: "Lateral Raise", setCount: 3, targetReps: 15),
                ExercisePlan(exerciseName: "Triceps Pushdown", setCount: 3, targetReps: 12),
            ]),
            WorkoutPlan(name: "PPL · Pull", exercises: [
                ExercisePlan(exerciseName: "Barbell Row", setCount: 4, targetReps: 8),
                ExercisePlan(exerciseName: "Pull-Up", setCount: 3, targetReps: 8),
                ExercisePlan(exerciseName: "Lat Pulldown", setCount: 3, targetReps: 12),
                ExercisePlan(exerciseName: "Face Pull", setCount: 3, targetReps: 15),
                ExercisePlan(exerciseName: "Barbell Curl", setCount: 3, targetReps: 12),
            ]),
            WorkoutPlan(name: "PPL · Legs", exercises: [
                ExercisePlan(exerciseName: "Back Squat", setCount: 4, targetReps: 8),
                ExercisePlan(exerciseName: "Romanian Deadlift", setCount: 3, targetReps: 10),
                ExercisePlan(exerciseName: "Leg Press", setCount: 3, targetReps: 12),
                ExercisePlan(exerciseName: "Lying Leg Curl", setCount: 3, targetReps: 12),
                ExercisePlan(exerciseName: "Standing Calf Raise", setCount: 4, targetReps: 15),
            ]),
        ]
    )

    /// Full-Body Beginner: a single, do-everything session for new lifters to run
    /// three times a week.
    private static let fullBodyBeginner = Program(
        id: "full-body-beginner",
        name: "Full-Body Beginner",
        tagline: "One session hitting every major muscle · 3× per week",
        overview: """
        A single full-body workout that trains every major muscle group in one \
        session. Perfect for getting started: run it three non-consecutive days a \
        week and add weight or reps as the movements start to feel easy.
        """,
        workouts: [
            WorkoutPlan(name: "Full-Body Beginner", exercises: [
                ExercisePlan(exerciseName: "Back Squat", setCount: 3, targetReps: 8),
                ExercisePlan(exerciseName: "Barbell Bench Press", setCount: 3, targetReps: 8),
                ExercisePlan(exerciseName: "Barbell Row", setCount: 3, targetReps: 8),
                ExercisePlan(exerciseName: "Overhead Press", setCount: 3, targetReps: 10),
                ExercisePlan(exerciseName: "Romanian Deadlift", setCount: 3, targetReps: 10),
                ExercisePlan(exerciseName: "Hanging Leg Raise", setCount: 3, targetReps: 12),
            ]),
        ]
    )
}
