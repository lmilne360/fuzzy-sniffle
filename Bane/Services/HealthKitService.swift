import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

/// Pure, platform-agnostic mapping logic for the Apple Health bridge.
///
/// Kept free of any `HealthKit` import so the interesting decisions — how a
/// finished ``Workout`` maps to a workout sample's time span, and whether an
/// imported bodyweight sample should become a new ``BodyMeasurement`` — are
/// exercisable as plain value functions in unit tests. ``HealthKitService``
/// leans on these and adds only the thin `HKHealthStore` plumbing.
enum HealthKitSync {
    /// The time span a finished workout occupies, used to build the Health
    /// workout sample.
    struct WorkoutSummary: Equatable {
        let start: Date
        let end: Date
        /// `end − start`, never negative.
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    /// Derives the Health time span for `workout`, or `nil` when the session is
    /// not finished (nothing to export yet).
    ///
    /// The start falls back to the workout's calendar `date` when `startedAt`
    /// was never stamped, and the end is floored to the start so a clock skew
    /// can never yield a negative duration.
    static func summary(for workout: Workout) -> WorkoutSummary? {
        guard let end = workout.finishedAt else { return nil }
        let start = workout.startedAt ?? workout.date
        return WorkoutSummary(start: start, end: max(start, end))
    }

    /// Whether a bodyweight sample dated `sampleDate` should be imported as a new
    /// measurement, given the measurements already on file.
    ///
    /// Skips the import when an entry recorded on the same calendar day already
    /// carries a weight, so repeated imports (or a manual entry the user already
    /// made that day) don't pile up duplicate snapshots.
    static func shouldImport(
        bodyMassDate sampleDate: Date,
        existing: [BodyMeasurement],
        calendar: Calendar = .current
    ) -> Bool {
        !existing.contains { measurement in
            measurement.weight != nil
                && calendar.isDate(measurement.date, inSameDayAs: sampleDate)
        }
    }
}

#if canImport(HealthKit)

/// Bridges the app to Apple Health: writes finished workouts and reads the
/// user's latest bodyweight.
///
/// A thin, best-effort wrapper over `HKHealthStore`. All access is funnelled
/// through the `@MainActor` ``shared`` instance because it is driven directly
/// from SwiftUI actions. Bodyweight crosses the boundary in **pounds** to match
/// the unitless-but-lb convention the rest of the model documents.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    /// The bodyweight quantity, shared by the read query and the auth request.
    private let bodyMassType = HKQuantityType(.bodyMass)

    private init() {}

    /// `true` when the device exposes a Health database (all iPhones; not iPad).
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests permission to write workouts and read bodyweight.
    ///
    /// Returns `false` when Health is unavailable or the request throws;
    /// callers treat that as "skip the sync". Note that HealthKit deliberately
    /// hides whether the user *granted* read access, so a `true` here only means
    /// the prompt completed.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(
                toShare: [HKQuantityType.workoutType()],
                read: [bodyMassType]
            )
            return true
        } catch {
            return false
        }
    }

    /// Writes `workout` to Health as a traditional strength-training session.
    ///
    /// Best-effort: silently returns if Health is unavailable, authorization
    /// fails, or the workout has not finished. Uses `HKWorkoutBuilder` (the
    /// non-deprecated path) to record the session's time span.
    func save(_ workout: Workout) async {
        guard isAvailable, let summary = HealthKitSync.summary(for: workout) else { return }
        guard await requestAuthorization() else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: configuration,
            device: .local()
        )
        do {
            try await builder.beginCollection(at: summary.start)
            try await builder.endCollection(at: summary.end)
            _ = try await builder.finishWorkout()
        } catch {
            // Best-effort export; nothing actionable to surface to the user.
        }
    }

    /// Reads the most recently recorded bodyweight from Health, in pounds, or
    /// `nil` when none is available (or access was denied).
    func latestBodyMass() async -> (weight: Double, date: Date)? {
        guard isAvailable, await requestAuthorization() else { return nil }

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMassType)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return (sample.quantity.doubleValue(for: .pound()), sample.endDate)
    }
}

#endif
