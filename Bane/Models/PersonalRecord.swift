import Foundation
import SwiftData

/// The kind of personal record tracked per exercise.
///
/// Each metric is derived from a single working set (warm-ups excluded), so a
/// record always points back to a concrete reps × weight performance.
enum PRMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    /// The single heaviest weight lifted for any rep count.
    case heaviestWeight
    /// The best Epley-estimated one-rep max across all sets.
    case estimatedOneRepMax
    /// The highest single-set volume (reps × weight).
    case bestSetVolume

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heaviestWeight: return "Heaviest Weight"
        case .estimatedOneRepMax: return "Est. 1RM"
        case .bestSetVolume: return "Best Set Volume"
        }
    }

    /// SF Symbol used to badge the record in lists.
    var systemImage: String {
        switch self {
        case .heaviestWeight: return "scalemass"
        case .estimatedOneRepMax: return "chart.line.uptrend.xyaxis"
        case .bestSetVolume: return "square.stack.3d.up"
        }
    }
}

/// A cached personal record for one exercise and one ``PRMetric``.
///
/// This model is a *derived cache*: the source of truth is workout history, and
/// ``PersonalRecordsService`` recomputes and upserts these rows on the read side
/// (when the Records or exercise-detail screens appear). Persisting the cache
/// lets those screens drive off a fast `@Query` instead of re-scanning history
/// on every render.
///
/// `exercise` is a plain reference (not owned): deleting an exercise nullifies
/// it, and the next refresh prunes the orphaned record.
@Model
final class PersonalRecord {
    var id: UUID = UUID()
    /// Which metric this row records.
    var metric: PRMetric = .heaviestWeight
    /// The metric's value — weight, estimated 1RM, or set volume depending on
    /// ``metric``. Unitless, mirroring the rest of the data model.
    var value: Double = 0
    /// Reps of the set that achieved the record.
    var reps: Int = 0
    /// Weight of the set that achieved the record.
    var weight: Double = 0
    /// The workout date on which the record was set.
    var achievedOn: Date = Date()
    /// The exercise the record belongs to.
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        metric: PRMetric,
        value: Double,
        reps: Int,
        weight: Double,
        achievedOn: Date,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.metric = metric
        self.value = value
        self.reps = reps
        self.weight = weight
        self.achievedOn = achievedOn
        self.exercise = exercise
    }
}
