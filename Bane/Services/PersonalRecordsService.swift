import Foundation
import SwiftData

/// Computes personal records from workout history and keeps the persisted
/// ``PersonalRecord`` cache in sync.
///
/// The heavy lifting lives in pure functions over plain values (``candidates``
/// / ``bestRecords``) so the record logic is independent of SwiftData and easy
/// to reason about. ``refresh(in:)`` wires those functions to the store,
/// rebuilding the cache from scratch on each call — cheap given the cache holds
/// at most `exercises × PRMetric.allCases` rows, and immune to the stale-row
/// bugs an incremental cache would invite.
///
/// This is strictly read-side: it is invoked when the Records or exercise
/// detail screens appear, never from the active-workout logging loop.
enum PersonalRecordsService {

    /// A single set's contribution to the record search, flattened out of the
    /// SwiftData object graph so record selection can be a pure function.
    struct Candidate {
        var reps: Int
        var weight: Double
        var date: Date

        /// Epley estimated one-rep max: `weight × (1 + reps / 30)`. Equals the
        /// weight itself for a single rep.
        var estimatedOneRepMax: Double {
            weight * (1 + Double(reps) / 30)
        }

        /// Single-set volume: `reps × weight`.
        var volume: Double {
            Double(reps) * weight
        }

        /// The candidate's raw value for a given metric.
        func value(for metric: PRMetric) -> Double {
            switch metric {
            case .heaviestWeight: return weight
            case .estimatedOneRepMax: return estimatedOneRepMax
            case .bestSetVolume: return volume
            }
        }
    }

    /// A computed record before it is persisted.
    struct Result {
        var metric: PRMetric
        var value: Double
        var reps: Int
        var weight: Double
        var date: Date
    }

    // MARK: - Pure computation

    /// Extracts every record-eligible set for `exercise` from `workouts`.
    ///
    /// Only finished sessions count as history, warm-ups are excluded (per
    /// ``SetEntry/isWarmup``), and a set must have both positive reps and
    /// positive weight to qualify — a zero on either axis can't set a
    /// weight/1RM/volume record.
    static func candidates(for exercise: Exercise, in workouts: [Workout]) -> [Candidate] {
        var result: [Candidate] = []
        for workout in workouts where workout.isFinished {
            for workoutExercise in workout.exercises
            where workoutExercise.exercise?.id == exercise.id {
                for set in workoutExercise.sets
                where !set.isWarmup && set.reps > 0 && set.weight > 0 {
                    result.append(Candidate(reps: set.reps, weight: set.weight, date: workout.date))
                }
            }
        }
        return result
    }

    /// Picks the best candidate for each metric.
    ///
    /// Ties break toward the earliest date, so a record reflects the first time
    /// the mark was hit. Returns an empty array when there are no candidates.
    static func bestRecords(from candidates: [Candidate]) -> [Result] {
        guard !candidates.isEmpty else { return [] }
        return PRMetric.allCases.compactMap { metric in
            let best = candidates.max { lhs, rhs in
                let l = lhs.value(for: metric)
                let r = rhs.value(for: metric)
                if l != r { return l < r }
                // Equal metric value: prefer the earlier date (keep it as the
                // "best" so `max` does not replace it with a later tie).
                return lhs.date > rhs.date
            }
            guard let best else { return nil }
            return Result(
                metric: metric,
                value: best.value(for: metric),
                reps: best.reps,
                weight: best.weight,
                date: best.date
            )
        }
    }

    /// Convenience: the current records for one exercise, computed live from
    /// history without touching the cache. Used by the exercise detail screen so
    /// it always reflects the latest sessions.
    static func records(for exercise: Exercise, in workouts: [Workout]) -> [Result] {
        bestRecords(from: candidates(for: exercise, in: workouts))
    }

    // MARK: - Cache maintenance

    /// Rebuilds the persisted ``PersonalRecord`` cache from current history.
    ///
    /// Wipes existing rows and re-inserts a fresh set, so records added, beaten,
    /// or invalidated by deleted workouts/exercises are all reconciled in one
    /// pass. Safe to call on every screen appearance.
    static func refresh(in context: ModelContext) {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []

        // Clear the old cache.
        for existing in (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? [] {
            context.delete(existing)
        }

        // Rebuild from history.
        for exercise in exercises {
            for result in records(for: exercise, in: workouts) {
                context.insert(
                    PersonalRecord(
                        metric: result.metric,
                        value: result.value,
                        reps: result.reps,
                        weight: result.weight,
                        achievedOn: result.date,
                        exercise: exercise
                    )
                )
            }
        }
    }
}
