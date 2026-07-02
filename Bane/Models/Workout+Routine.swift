import Foundation
import SwiftData

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
        build(from: routine) { item in
            item.orderedSets.map { ProgressiveOverload.SetTarget(reps: $0.targetReps, weight: $0.targetWeight) }
        }
    }

    /// Builds an in-progress workout from a routine, applying double-progression
    /// targets when the routine has ``Routine/progressiveOverloadEnabled`` set
    /// (ba-3hk).
    ///
    /// For each item, the previous session's working sets are read from finished
    /// workout history — the most recent finished workout that performed the same
    /// exercise — and run through ``ProgressiveOverload/nextTargets(previousWorkingSets:min:max:increment:fallback:)``.
    /// With no history (or with the mode off) this falls back to the routine's
    /// configured targets, i.e. the same result as ``from(routine:)``.
    ///
    /// `Workout` carries no routine reference, so history is matched per
    /// exercise across all finished sessions rather than per routine — the
    /// double-progression method tracks the exercise's last performance
    /// regardless of which template logged it.
    static func fromProgressive(routine: Routine, in context: ModelContext) -> Workout {
        guard routine.progressiveOverloadEnabled else { return from(routine: routine) }

        let finished = (try? context.fetch(FetchDescriptor<Workout>())) ?? []

        return build(from: routine) { item in
            let fallback = item.orderedSets.map {
                ProgressiveOverload.SetTarget(reps: $0.targetReps, weight: $0.targetWeight)
            }
            guard let exercise = item.exercise,
                  let previous = latestWorkingSets(for: exercise, in: finished) else {
                return fallback
            }
            return ProgressiveOverload.nextTargets(
                previousWorkingSets: previous,
                min: item.effectiveRepRangeMin,
                max: item.effectiveRepRangeMax,
                increment: item.effectiveWeightIncrement,
                fallback: fallback
            )
        }
    }

    /// Shared assembly: turns each routine item into a `WorkoutExercise` seeded
    /// with the set targets produced by `targets`.
    private static func build(
        from routine: Routine,
        targets: (RoutineItem) -> [ProgressiveOverload.SetTarget]
    ) -> Workout {
        let workout = Workout(startedAt: .now)

        var exerciseOrder = 0
        for item in routine.orderedItems {
            guard let exercise = item.exercise else { continue }

            let workoutExercise = WorkoutExercise(order: exerciseOrder, exercise: exercise)
            workoutExercise.workout = workout
            workout.exercises.append(workoutExercise)
            exerciseOrder += 1

            for (setOrder, target) in targets(item).enumerated() {
                let set = SetEntry(
                    order: setOrder,
                    reps: target.reps,
                    weight: target.weight
                )
                set.workoutExercise = workoutExercise
                workoutExercise.sets.append(set)
            }
        }

        return workout
    }

    /// The working sets (warm-ups excluded, in set order) that `exercise` was
    /// performed with in its most recent finished workout, or `nil` when the
    /// exercise has no finished history.
    private static func latestWorkingSets(
        for exercise: Exercise,
        in workouts: [Workout]
    ) -> [ProgressiveOverload.PreviousSet]? {
        let mostRecent = workouts
            .filter { workout in
                workout.isFinished && workout.exercises.contains { performed in
                    performed.exercise?.id == exercise.id
                        && performed.sets.contains { !$0.isWarmup }
                }
            }
            .max { lhs, rhs in lhs.date < rhs.date }

        guard let workout = mostRecent else { return nil }

        let sets = workout.orderedExercises
            .filter { $0.exercise?.id == exercise.id }
            .flatMap { $0.orderedSets }
            .filter { !$0.isWarmup }
            .map { ProgressiveOverload.PreviousSet(reps: $0.reps, weight: $0.weight) }

        return sets.isEmpty ? nil : sets
    }
}
