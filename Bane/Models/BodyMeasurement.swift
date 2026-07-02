import Foundation
import SwiftData

/// A dated snapshot of the user's body: bodyweight, body-fat %, and the common
/// tape-measure circumferences people track alongside training progress.
///
/// Every metric except ``date`` is optional so a snapshot can record just the
/// values the user actually measured that day (e.g. weight only, or a full set
/// of circumferences). All lengths are unitless, mirroring the rest of the data
/// model — unit handling is a UI concern. Weight uses the same unitless
/// convention as `SetEntry.weight`.
@Model
final class BodyMeasurement {
    var id: UUID = UUID()
    /// The day the measurement was taken; also the primary sort/grouping key.
    var date: Date = Date.now

    /// Bodyweight, in the user's preferred unit.
    var weight: Double?
    /// Body-fat percentage, expressed as a whole-number percent (e.g. `18.5`).
    var bodyFatPercentage: Double?

    // MARK: Circumferences

    var neck: Double?
    var shoulders: Double?
    var chest: Double?
    var waist: Double?
    var hips: Double?
    /// Upper-arm (biceps) circumference — left and right tracked separately.
    var leftArm: Double?
    var rightArm: Double?
    var leftThigh: Double?
    var rightThigh: Double?
    var leftCalf: Double?
    var rightCalf: Double?

    /// Free-form note for the entry (conditions, measurement caveats, etc.).
    var notes: String = ""

    init(
        id: UUID = UUID(),
        date: Date = .now,
        weight: Double? = nil,
        bodyFatPercentage: Double? = nil,
        neck: Double? = nil,
        shoulders: Double? = nil,
        chest: Double? = nil,
        waist: Double? = nil,
        hips: Double? = nil,
        leftArm: Double? = nil,
        rightArm: Double? = nil,
        leftThigh: Double? = nil,
        rightThigh: Double? = nil,
        leftCalf: Double? = nil,
        rightCalf: Double? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
        self.neck = neck
        self.shoulders = shoulders
        self.chest = chest
        self.waist = waist
        self.hips = hips
        self.leftArm = leftArm
        self.rightArm = rightArm
        self.leftThigh = leftThigh
        self.rightThigh = rightThigh
        self.leftCalf = leftCalf
        self.rightCalf = rightCalf
        self.notes = notes
    }

    /// `true` when the entry records no numeric value at all — used to keep empty
    /// snapshots out of the store.
    var isEmpty: Bool {
        allFields.allSatisfy { $0.value == nil }
    }

    /// Every numeric field paired with its display label, in head-to-toe order.
    /// Drives both the entry form and the history rows so the two never drift.
    var allFields: [(label: String, value: Double?)] {
        [
            ("Weight", weight),
            ("Body Fat %", bodyFatPercentage),
            ("Neck", neck),
            ("Shoulders", shoulders),
            ("Chest", chest),
            ("Waist", waist),
            ("Hips", hips),
            ("Left Arm", leftArm),
            ("Right Arm", rightArm),
            ("Left Thigh", leftThigh),
            ("Right Thigh", rightThigh),
            ("Left Calf", leftCalf),
            ("Right Calf", rightCalf),
        ]
    }

    /// The subset of ``allFields`` that were actually recorded.
    var recordedFields: [(label: String, value: Double?)] {
        allFields.filter { $0.value != nil }
    }
}
