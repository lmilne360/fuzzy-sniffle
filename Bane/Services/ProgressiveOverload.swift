import Foundation

/// Double-progression logic for routines running in Progressive Overload mode
/// (ba-3hk).
///
/// The rule, per exercise, given the previous session's **working** sets
/// (warm-ups excluded) and a rep range `[min, max]` with a weight `increment`:
///
/// - **All working sets reached `max`** → add `increment` to each set's weight
///   and reset its reps to `min` (same set count). The load went up; start the
///   range over.
/// - **Any working set fell below `min`** → hold: keep each set's weight, target
///   `min` reps. Don't pile on more load while still building the base.
/// - **Otherwise (progressing within the range)** → keep each set's weight and
///   add one rep toward the top (`min(prevReps + 1, max)`).
/// - **No prior history** → fall back to the routine's configured starting
///   targets, i.e. the plain ``Workout/from(routine:)`` seeding.
///
/// The core is a pure function over plain values (``nextTargets(previousWorkingSets:min:max:increment:)``)
/// so it is independent of SwiftData and directly unit-testable, mirroring
/// ``PersonalRecordsService``. Weights are canonical pounds throughout; unit
/// display/entry happens at the UI boundary.
enum ProgressiveOverload {
    /// Rep-range floor used when a routine item leaves ``RoutineItem/repRangeMin`` unset.
    static let defaultMinReps = 8
    /// Rep-range ceiling used when a routine item leaves ``RoutineItem/repRangeMax`` unset.
    static let defaultMaxReps = 12
    /// Weight step (canonical pounds) used when ``RoutineItem/weightIncrement`` is unset.
    static let defaultIncrementPounds = 5.0

    /// One planned set for the next session: the reps and canonical-pounds
    /// weight to seed into the active workout.
    struct SetTarget: Equatable {
        var reps: Int
        var weight: Double
    }

    /// The reps and weight actually performed on one working set last time.
    struct PreviousSet: Equatable {
        var reps: Int
        var weight: Double
    }

    /// Computes the next session's targets for a single exercise.
    ///
    /// `previousWorkingSets` must already exclude warm-ups and be in set order.
    /// When it is empty there is no history to progress from, so the caller's
    /// `fallback` (the routine's configured targets) is returned unchanged.
    static func nextTargets(
        previousWorkingSets: [PreviousSet],
        min minReps: Int,
        max maxReps: Int,
        increment: Double,
        fallback: [SetTarget]
    ) -> [SetTarget] {
        guard !previousWorkingSets.isEmpty else { return fallback }

        // Guard against an inverted or degenerate range so the arithmetic below
        // stays well-behaved even with odd user input.
        let low = Swift.min(minReps, maxReps)
        let high = Swift.max(minReps, maxReps)

        let allReachedMax = previousWorkingSets.allSatisfy { $0.reps >= high }
        let anyBelowMin = previousWorkingSets.contains { $0.reps < low }

        return previousWorkingSets.map { set in
            if allReachedMax {
                // Whole range cleared → bump the load, restart at the bottom.
                return SetTarget(reps: low, weight: set.weight + increment)
            }
            if anyBelowMin {
                // Still under the floor somewhere → hold load, aim for the floor.
                return SetTarget(reps: low, weight: set.weight)
            }
            // Mid-range → keep the load, add a rep toward the top.
            return SetTarget(reps: Swift.min(set.reps + 1, high), weight: set.weight)
        }
    }
}
