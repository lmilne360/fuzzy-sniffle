import Foundation

extension Workout {
    /// Builds an in-progress workout pre-populated from a routine template.
    ///
    /// Each routine item becomes a `WorkoutExercise` (in the routine's order),
    /// seeded with one `SetEntry` per target `RoutineSet` — pre-filled with the
    /// routine's target reps and weight so the active workout opens ready to
    /// check off or adjust (e.g. Set 1 = 10 reps @ 100 lb). Items whose exercise
    /// was deleted out from under the routine are skipped, and remaining orders
    /// stay contiguous.
    ///
    /// The returned workout and its children are fully wired via relationships
    /// but **not** inserted into any model context — the caller owns insertion
    /// (mirroring `ActiveWorkoutView`'s ownership model).
    static func from(routine: Routine) -> Workout {
        let workout = Workout(startedAt: .now)

        var exerciseOrder = 0
        for item in routine.orderedItems {
            guard let exercise = item.exercise else { continue }

            let workoutExercise = WorkoutExercise(order: exerciseOrder, exercise: exercise)
            workoutExercise.workout = workout
            workout.exercises.append(workoutExercise)
            exerciseOrder += 1

            for (setOrder, target) in item.orderedSets.enumerated() {
                let set = SetEntry(
                    order: setOrder,
                    reps: target.targetReps,
                    weight: target.targetWeight
                )
                set.workoutExercise = workoutExercise
                workoutExercise.sets.append(set)
            }
        }

        return workout
    }
}
