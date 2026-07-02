import Foundation

/// Pure barbell-loading math: given a target weight, the bar, and which plates
/// are on hand, work out the per-side plate breakdown.
///
/// Unit-agnostic — it operates on the same numeric scale the rest of the app
/// uses for weight (see `SetEntry.weight`), so callers decide whether the
/// numbers mean pounds or kilograms.
enum PlateCalculator {
    /// A run of identical plates loaded on *one* side of the bar.
    struct Placement: Identifiable, Equatable {
        /// Denomination of the plate.
        let plate: Double
        /// How many of this plate go on each side.
        let count: Int

        var id: Double { plate }
    }

    /// The outcome of loading `target` onto `barWeight` with `plates`.
    struct Loadout: Equatable {
        let target: Double
        let barWeight: Double
        /// Plates per side, heaviest first.
        let perSide: [Placement]
        /// Weight actually achievable with the available plates — equal to
        /// `target` when it can be matched exactly.
        let achieved: Double

        /// Unmatched weight left over after greedily loading whole plates.
        /// Zero (within a rounding epsilon) when the target is exact.
        var remainder: Double { max(0, target - achieved) }

        /// `true` when the plates land exactly on the target.
        var isExact: Bool { remainder < Self.epsilon }

        /// `true` when the target is below the bar itself — nothing to load.
        var isBelowBar: Bool { target < barWeight - Self.epsilon }

        /// Total plate weight on a single side.
        var perSideWeight: Double {
            perSide.reduce(0) { $0 + $1.plate * Double($1.count) }
        }

        static let epsilon = 0.001
    }

    /// Greedily load `target` onto the bar using the largest plates first.
    ///
    /// Only whole plates are placed and both sides stay symmetric, so a target
    /// that can't be matched exactly leaves a `remainder`. Returns an empty
    /// loadout (with a full remainder) when the target is at or below the bar.
    static func solve(
        target: Double,
        barWeight: Double,
        plates: [Double]
    ) -> Loadout {
        guard target > barWeight + Loadout.epsilon else {
            return Loadout(
                target: target,
                barWeight: barWeight,
                perSide: [],
                achieved: min(target, barWeight)
            )
        }

        // Work per side against half the plate weight; both sides mirror.
        var remainingPerSide = (target - barWeight) / 2
        var placements: [Placement] = []

        for plate in plates.sorted(by: >) where plate > 0 {
            let count = Int((remainingPerSide + Loadout.epsilon) / plate)
            guard count > 0 else { continue }
            placements.append(Placement(plate: plate, count: count))
            remainingPerSide -= Double(count) * plate
        }

        let loadedPerSide = placements.reduce(0) { $0 + $1.plate * Double($1.count) }
        return Loadout(
            target: target,
            barWeight: barWeight,
            perSide: placements,
            achieved: barWeight + loadedPerSide * 2
        )
    }
}

/// Shared storage keys, defaults, and encoding for plate-calculator
/// preferences, so the calculator sheet and any future settings surface agree
/// on the contract.
enum PlatePreferences {
    static let barWeightKey = "plateBarWeight"
    static let availablePlatesKey = "plateAvailablePlates"

    /// Standard Olympic bar weight (lb) used until the user picks another.
    static let fallbackBarWeight: Double = 45

    /// Common bar weights offered in the picker.
    static let barPresets: [Double] = [45, 35, 15, 0]

    /// Full set of denominations the user can toggle on or off, heaviest first.
    static let selectablePlates: [Double] = [45, 35, 25, 15, 10, 5, 2.5, 1.25]

    /// Plates available out of the box: a typical home/commercial lb set.
    static let fallbackPlates: [Double] = [45, 25, 10, 5, 2.5]

    /// Encodes a plate set for `AppStorage` (which can't hold arrays directly).
    static func encode(_ plates: [Double]) -> String {
        plates.sorted(by: >).map { Formatting.plate($0) }.joined(separator: ",")
    }

    /// Decodes a stored plate set, falling back to the default when empty or
    /// malformed.
    static func decode(_ raw: String) -> [Double] {
        let parsed = raw
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 }
        return parsed.isEmpty ? fallbackPlates : Array(Set(parsed)).sorted(by: >)
    }
}

/// Number formatting shared by the plate calculator — trims trailing zeros so
/// `2.5` and `45` both read cleanly.
enum Formatting {
    /// A plate/weight value without needless decimals (`45`, `2.5`).
    static func plate(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }
}
