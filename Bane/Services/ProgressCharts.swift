import Foundation

/// Read-only aggregation of workout history and body measurements into the time
/// series the Charts screen plots. Like ``MuscleHeatMap`` this is a pure
/// computation over already-fetched models — it never mutates the store — so it
/// is equally usable from views, previews, and tests.
///
/// The estimated-1RM series is built on top of ``PersonalRecordsService`` so the
/// charted 1RM matches the number the Records screen reports (same Epley formula,
/// same warm-up / positive-set filtering).
enum ProgressCharts {

    /// A single dated point in a chart series. `value` is unitless, mirroring the
    /// rest of the model (weight/volume carry no unit at this layer).
    struct DataPoint: Identifiable {
        let date: Date
        let value: Double

        var id: Date { date }
    }

    /// Best estimated one-rep max per training day for `exercise`, ascending by
    /// date.
    ///
    /// Reuses ``PersonalRecordsService/candidates(for:in:)`` — which already
    /// flattens finished sessions to positive-weight working sets — then collapses
    /// each calendar day to its single best Epley estimate. Charting per day (not
    /// per set) keeps the line readable while still showing the progression that
    /// earns the 1RM record.
    static func estimatedOneRepMaxOverTime(
        for exercise: Exercise,
        in workouts: [Workout]
    ) -> [DataPoint] {
        let candidates = PersonalRecordsService.candidates(for: exercise, in: workouts)
        let calendar = Calendar.current

        var bestByDay: [Date: Double] = [:]
        for candidate in candidates {
            let day = calendar.startOfDay(for: candidate.date)
            let estimate = candidate.estimatedOneRepMax
            if estimate > (bestByDay[day] ?? 0) {
                bestByDay[day] = estimate
            }
        }

        return bestByDay
            .map { DataPoint(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    /// Total working volume per finished session, ascending by date.
    ///
    /// One point per finished workout using its `date` and ``Workout/totalVolume``
    /// (warm-ups already excluded). Sessions with zero working volume are dropped
    /// so an abandoned or warm-up-only session doesn't flatten the trend.
    static func volumePerSession(in workouts: [Workout]) -> [DataPoint] {
        workouts
            .filter { $0.isFinished }
            .map { DataPoint(date: $0.date, value: $0.totalVolume) }
            .filter { $0.value > 0 }
            .sorted { $0.date < $1.date }
    }

    /// Bodyweight over time, ascending by date.
    ///
    /// Only measurements that actually recorded a weight contribute a point; a
    /// snapshot that captured circumferences but no weight is skipped.
    static func bodyweightOverTime(in measurements: [BodyMeasurement]) -> [DataPoint] {
        measurements
            .compactMap { measurement in
                measurement.weight.map { DataPoint(date: measurement.date, value: $0) }
            }
            .sorted { $0.date < $1.date }
    }
}
