import SwiftUI

/// A user-selectable unit for displaying and entering weights.
///
/// The data model stores **every** weight in pounds — `SetEntry.weight`,
/// `RoutineSet.targetWeight`, `PlatePreferences.barWeight`, and
/// `BodyMeasurement.weight` are all canonical lb. This type converts and formats
/// at the UI boundary only; stored values are never migrated (ba-w6o).
enum WeightUnit: String, CaseIterable, Identifiable, Sendable {
    case pounds
    case kilograms

    var id: String { rawValue }

    /// Short label shown beside values (`lb` / `kg`).
    var abbreviation: String {
        switch self {
        case .pounds: return "lb"
        case .kilograms: return "kg"
        }
    }

    /// Full name for the settings picker.
    var displayName: String {
        switch self {
        case .pounds: return "Pounds"
        case .kilograms: return "Kilograms"
        }
    }

    /// Exact pounds in one kilogram; every conversion routes through this.
    /// Round-tripping a value entered in kg back to lb and forward again drifts
    /// slightly — that's accepted (ba-w6o) since canonical storage stays lb.
    static let poundsPerKilogram = 2.2046226218

    /// Converts a canonical pounds value into this unit for display.
    func fromPounds(_ pounds: Double) -> Double {
        switch self {
        case .pounds: return pounds
        case .kilograms: return pounds / Self.poundsPerKilogram
        }
    }

    /// Converts a value entered in this unit back into canonical pounds.
    func toPounds(_ value: Double) -> Double {
        switch self {
        case .pounds: return value
        case .kilograms: return value * Self.poundsPerKilogram
        }
    }
}

/// Shared storage contract for the weight-unit preference, so the settings
/// screen and every weight surface agree on the key and default.
///
/// The default is `.pounds`: the app has always shown pounds, and existing
/// installs have no stored key, so behavior is unchanged until the user opts in.
enum WeightPreferences {
    static let unitKey = "weightUnit"

    /// The out-of-box unit before the user customizes it.
    static let fallback = WeightUnit.pounds
}

/// Formats canonical-pounds weights for display in a chosen ``WeightUnit`` so
/// every surface renders and labels weights identically.
enum WeightFormat {
    /// The bare converted number, trimmed to at most one decimal (`100`, `45.4`),
    /// for fields or pickers that show the unit label separately.
    static func value(_ pounds: Double, in unit: WeightUnit) -> String {
        unit.fromPounds(pounds).formatted(.number.precision(.fractionLength(0...1)))
    }

    /// A single weight with its unit label (`100 lb`, `45.4 kg`).
    static func weight(_ pounds: Double, in unit: WeightUnit) -> String {
        "\(value(pounds, in: unit)) \(unit.abbreviation)"
    }

    /// A grouped aggregate volume with its unit label (`12,340 lb`). Whole numbers
    /// only, matching the historical volume rendering.
    static func volume(_ pounds: Double, in unit: WeightUnit) -> String {
        let converted = unit.fromPounds(pounds).formatted(.number.precision(.fractionLength(0)))
        return "\(converted) \(unit.abbreviation)"
    }
}

extension Binding where Value == Double {
    /// Wraps a canonical-pounds binding so a text field can read and write in
    /// `unit`, converting at the boundary. The underlying value stays in pounds.
    func weightDisplay(in unit: WeightUnit) -> Binding<Double> {
        Binding<Double>(
            get: { unit.fromPounds(wrappedValue) },
            set: { wrappedValue = unit.toPounds($0) }
        )
    }
}
