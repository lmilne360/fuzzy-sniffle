import Foundation
import SwiftUI

/// The rolling window over which muscle training volume is aggregated for the
/// heat map. Values are day counts measured back from "now".
enum HeatMapWindow: Int, CaseIterable, Identifiable, Sendable {
    case week = 7
    case month = 30
    case quarter = 90

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .quarter: return "90 Days"
        }
    }

    /// The earliest workout date included in the window, measured back from
    /// `reference` (the start of that calendar day, so the whole first day is
    /// covered).
    func startDate(from reference: Date = .now) -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: .day, value: -(rawValue - 1), to: dayStart) ?? dayStart
    }
}

/// Aggregated working volume for a single muscle over the selected window.
struct MuscleVolume: Identifiable, Equatable {
    let muscle: Muscle
    /// Σ (reps × weight) across non-warm-up sets targeting this muscle.
    let volume: Double
    /// Number of non-warm-up sets that targeted this muscle.
    let setCount: Int

    var id: Muscle { muscle }
}

/// Read-only aggregation of recent training volume grouped by an exercise's
/// primary muscle, plus the color scale used to render the heat map.
///
/// This is a pure computation over already-fetched models — it never mutates
/// the store — so it is equally usable from views, previews, and tests.
enum MuscleHeatMap {
    /// Working volume per muscle across finished workouts on or after `since`.
    ///
    /// Volume is Σ (reps × weight) over non-warm-up sets, attributed to the
    /// performing exercise's ``Exercise/primaryMuscle``. Warm-ups are excluded
    /// to mirror ``Workout/totalVolume``. Exercises whose reference was deleted
    /// (nil `exercise`) are skipped. Only muscles with recorded volume appear.
    static func volumes(in workouts: [Workout], since: Date) -> [MuscleVolume] {
        var volumeByMuscle: [Muscle: Double] = [:]
        var setsByMuscle: [Muscle: Int] = [:]

        for workout in workouts where workout.isFinished && workout.date >= since {
            for workoutExercise in workout.exercises {
                guard let muscle = workoutExercise.exercise?.primaryMuscle else { continue }
                for set in workoutExercise.sets where !set.isWarmup {
                    volumeByMuscle[muscle, default: 0] += Double(set.reps) * set.weight
                    setsByMuscle[muscle, default: 0] += 1
                }
            }
        }

        return volumeByMuscle.map { muscle, volume in
            MuscleVolume(muscle: muscle, volume: volume, setCount: setsByMuscle[muscle] ?? 0)
        }
    }

    /// Maps a normalized intensity (0...1) to a heat color.
    ///
    /// Zero — an untrained muscle — reads as a neutral gray. Trained muscles
    /// sweep from cool green (low volume) through amber to hot red (the most
    /// trained muscle in the window), so relative emphasis is visible at a
    /// glance and reinforced by the legend.
    static func heatColor(for intensity: Double) -> Color {
        guard intensity > 0 else { return Color(.systemGray5) }
        let clamped = min(max(intensity, 0), 1)
        // Hue 0.33 (green) at the low end sweeping to 0.0 (red) at the top.
        let hue = 0.33 * (1 - clamped)
        return Color(hue: hue, saturation: 0.85, brightness: 0.9)
    }
}
