import Foundation

/// Pure warm-up ramp math: from a working weight, produce a ladder of lighter
/// warm-up sets at fixed percentages, each rounded to a loadable increment.
///
/// Unit-agnostic like ``PlateCalculator`` — it operates on the same numeric
/// weight scale as `SetEntry.weight`, so callers decide whether the numbers mean
/// pounds or kilograms.
enum WarmupCalculator {
    /// One rung of a warm-up ramp: a fraction of the working weight and the reps
    /// to perform there.
    struct Step: Equatable {
        /// Fraction of the working weight, in `0...1`.
        let percentage: Double
        let reps: Int
    }

    /// A concrete warm-up set produced from a ``Step`` and a working weight.
    struct WarmupSet: Identifiable, Equatable {
        /// The scheme fraction this rung came from — also its stable identity.
        let percentage: Double
        /// Weight rounded to the caller's increment and floored at the bar.
        let weight: Double
        let reps: Int

        var id: Double { percentage }
    }

    /// Builds the warm-up ladder leading up to `workingWeight`.
    ///
    /// Each step's raw weight (`workingWeight × percentage`) is rounded to the
    /// nearest `rounding` increment and floored at `barWeight`, so no rung asks
    /// for less than an empty bar. Rungs that round to or above the working
    /// weight — or that don't clear the previous kept rung — are dropped, so the
    /// ladder strictly ascends and never meets the working set. Returns an empty
    /// ladder when the working weight is at or below the bar.
    static func warmupSets(
        workingWeight: Double,
        scheme: [Step],
        rounding: Double = 5,
        barWeight: Double = 0
    ) -> [WarmupSet] {
        guard workingWeight > barWeight else { return [] }

        var ladder: [WarmupSet] = []
        for step in scheme {
            let raw = workingWeight * step.percentage
            let weight = max(barWeight, roundToIncrement(raw, increment: rounding))
            // A warm-up must stay below the working weight…
            guard weight < workingWeight else { continue }
            // …and strictly above the previous kept rung.
            if let last = ladder.last, weight <= last.weight { continue }
            ladder.append(WarmupSet(percentage: step.percentage, weight: weight, reps: step.reps))
        }
        return ladder
    }

    /// Rounds `value` to the nearest positive `increment`, falling back to whole
    /// numbers when the increment is non-positive.
    static func roundToIncrement(_ value: Double, increment: Double) -> Double {
        guard increment > 0 else { return value.rounded() }
        return (value / increment).rounded() * increment
    }
}

/// Named warm-up ramps plus the stored preferences (chosen ramp + rounding) so
/// the calculator sheet and any future settings surface agree on the contract.
enum WarmupPreferences {
    static let schemeKey = "warmupSchemeID"
    static let roundingKey = "warmupRounding"

    /// Rounding increment used until the user picks another.
    static let fallbackRounding: Double = 5
    /// Common rounding increments offered in the picker.
    static let roundingPresets: [Double] = [10, 5, 2.5, 1]

    /// The default ramp, used until the user picks another.
    static let fallbackSchemeID = "standard"

    /// A named warm-up ramp the user can choose between.
    struct Scheme: Identifiable, Equatable {
        let id: String
        let name: String
        let steps: [WarmupCalculator.Step]
    }

    /// Selectable ramps, from most to fewest sets.
    static let schemes: [Scheme] = [
        Scheme(
            id: "gradual",
            name: "Gradual",
            steps: [
                WarmupCalculator.Step(percentage: 0.40, reps: 8),
                WarmupCalculator.Step(percentage: 0.55, reps: 5),
                WarmupCalculator.Step(percentage: 0.70, reps: 3),
                WarmupCalculator.Step(percentage: 0.85, reps: 2),
            ]
        ),
        Scheme(
            id: "standard",
            name: "Standard",
            steps: [
                WarmupCalculator.Step(percentage: 0.40, reps: 8),
                WarmupCalculator.Step(percentage: 0.60, reps: 5),
                WarmupCalculator.Step(percentage: 0.80, reps: 3),
            ]
        ),
        Scheme(
            id: "minimal",
            name: "Minimal",
            steps: [
                WarmupCalculator.Step(percentage: 0.50, reps: 5),
                WarmupCalculator.Step(percentage: 0.75, reps: 3),
            ]
        ),
    ]

    /// The named ramp for `id`, falling back to ``fallbackSchemeID`` when unknown.
    static func scheme(id: String) -> Scheme {
        schemes.first { $0.id == id }
            ?? schemes.first { $0.id == fallbackSchemeID }
            ?? schemes[0]
    }
}
