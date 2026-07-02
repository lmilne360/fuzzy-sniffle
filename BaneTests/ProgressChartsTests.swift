import XCTest
import SwiftData
@testable import Bane

/// Unit tests for ``ProgressCharts`` — the pure aggregation behind the Charts
/// tab (ba-07l.2).
///
/// These build small in-memory object graphs and assert the three chart series
/// pick, group, filter, and sort their points as documented. The series are pure
/// functions over models, so no container round-trip is required — but tests run
/// on the main actor to match the rest of the suite.
@MainActor
final class ProgressChartsTests: XCTestCase {

    private let calendar = Calendar.current

    /// Builds a finished workout on `date` containing one exercise with the given
    /// (reps, weight, isWarmup) sets. Fully wired via relationships.
    private func finishedWorkout(
        on date: Date,
        exercise: Exercise,
        sets: [(reps: Int, weight: Double, warmup: Bool)]
    ) -> Workout {
        let workout = Workout(date: date, startedAt: date, finishedAt: date.addingTimeInterval(3600))
        let we = WorkoutExercise(order: 0, exercise: exercise)
        we.workout = workout
        we.sets = sets.enumerated().map { index, set in
            SetEntry(order: index, reps: set.reps, weight: set.weight, completed: true, isWarmup: set.warmup)
        }
        for set in we.sets { set.workoutExercise = we }
        workout.exercises = [we]
        return workout
    }

    private func makeExercise(_ name: String = "Bench Press") -> Exercise {
        Exercise(name: name, category: .chest, primaryMuscle: .chest, equipment: .barbell)
    }

    // MARK: - Estimated 1RM over time

    /// One point per training day, each holding that day's best Epley estimate,
    /// ascending by date.
    func testOneRepMaxOverTimePicksDailyBestAscending() {
        let exercise = makeExercise()
        let day1 = calendar.startOfDay(for: .now.addingTimeInterval(-7 * 86_400))
        let day2 = calendar.startOfDay(for: .now)

        // Day 1: best estimate is 100 × (1 + 5/30) ≈ 116.67 vs 95 × (1 + 5/30).
        let w1 = finishedWorkout(on: day1, exercise: exercise, sets: [
            (reps: 5, weight: 95, warmup: false),
            (reps: 5, weight: 100, warmup: false),
        ])
        // Day 2: 110 × (1 + 5/30) ≈ 128.33.
        let w2 = finishedWorkout(on: day2, exercise: exercise, sets: [
            (reps: 5, weight: 110, warmup: false),
        ])

        let series = ProgressCharts.estimatedOneRepMaxOverTime(for: exercise, in: [w2, w1])

        XCTAssertEqual(series.count, 2)
        XCTAssertEqual(series.map(\.date), [day1, day2], "Points must be ascending by date")
        XCTAssertEqual(series[0].value, 100 * (1 + 5.0 / 30), accuracy: 0.001)
        XCTAssertEqual(series[1].value, 110 * (1 + 5.0 / 30), accuracy: 0.001)
    }

    /// Multiple sessions on the same calendar day collapse to a single point
    /// holding the day's best estimate.
    func testOneRepMaxOverTimeCollapsesSameDaySessions() {
        let exercise = makeExercise()
        let morning = calendar.startOfDay(for: .now).addingTimeInterval(8 * 3600)
        let evening = calendar.startOfDay(for: .now).addingTimeInterval(18 * 3600)

        let am = finishedWorkout(on: morning, exercise: exercise, sets: [(reps: 5, weight: 100, warmup: false)])
        let pm = finishedWorkout(on: evening, exercise: exercise, sets: [(reps: 3, weight: 120, warmup: false)])

        let series = ProgressCharts.estimatedOneRepMaxOverTime(for: exercise, in: [am, pm])

        XCTAssertEqual(series.count, 1, "Same-day sessions should collapse to one point")
        XCTAssertEqual(series[0].value, 120 * (1 + 3.0 / 30), accuracy: 0.001,
                       "The point should hold the day's best estimate")
    }

    /// Warm-ups, zero-weight/zero-rep sets, and unfinished sessions never
    /// contribute a point — matching the PR service's candidate filtering.
    func testOneRepMaxOverTimeExcludesWarmupsAndUnfinished() {
        let exercise = makeExercise()
        let day = calendar.startOfDay(for: .now)

        let warmupOnly = finishedWorkout(on: day, exercise: exercise, sets: [
            (reps: 10, weight: 45, warmup: true),
            (reps: 5, weight: 0, warmup: false),
        ])
        let unfinished = Workout(date: day, startedAt: day)
        let we = WorkoutExercise(order: 0, exercise: exercise)
        we.workout = unfinished
        we.sets = [SetEntry(order: 0, reps: 5, weight: 200, completed: true)]
        for set in we.sets { set.workoutExercise = we }
        unfinished.exercises = [we]

        let series = ProgressCharts.estimatedOneRepMaxOverTime(for: exercise, in: [warmupOnly, unfinished])

        XCTAssertTrue(series.isEmpty,
                      "Warm-ups, zero-weight sets, and unfinished sessions should not chart")
    }

    // MARK: - Volume per session

    /// One point per finished session using its total working volume, ascending
    /// by date; unfinished sessions are excluded.
    func testVolumePerSessionSumsWorkingSetsAscending() {
        let exercise = makeExercise()
        let earlier = Date.now.addingTimeInterval(-2 * 86_400)
        let later = Date.now

        // 5×100 + 5×100 = 1000, warm-up excluded.
        let w1 = finishedWorkout(on: earlier, exercise: exercise, sets: [
            (reps: 5, weight: 100, warmup: false),
            (reps: 5, weight: 100, warmup: false),
            (reps: 10, weight: 45, warmup: true),
        ])
        // 3×200 = 600.
        let w2 = finishedWorkout(on: later, exercise: exercise, sets: [
            (reps: 3, weight: 200, warmup: false),
        ])
        let unfinished = Workout(date: later, startedAt: later)

        let series = ProgressCharts.volumePerSession(in: [w2, unfinished, w1])

        XCTAssertEqual(series.map(\.date), [earlier, later], "Points must be ascending by date")
        XCTAssertEqual(series.map(\.value), [1000, 600])
    }

    /// A finished session with no working volume (empty or warm-up-only) is
    /// dropped so it doesn't flatten the trend.
    func testVolumePerSessionDropsZeroVolumeSessions() {
        let exercise = makeExercise()
        let day = Date.now
        let warmupOnly = finishedWorkout(on: day, exercise: exercise, sets: [
            (reps: 10, weight: 45, warmup: true),
        ])

        XCTAssertTrue(ProgressCharts.volumePerSession(in: [warmupOnly]).isEmpty)
    }

    // MARK: - Bodyweight over time

    /// Only measurements that recorded a weight contribute a point, ascending by
    /// date.
    func testBodyweightOverTimeSkipsMeasurementsWithoutWeight() {
        let older = BodyMeasurement(date: .now.addingTimeInterval(-86_400), weight: 183)
        let newer = BodyMeasurement(date: .now, weight: 181)
        let weightless = BodyMeasurement(date: .now.addingTimeInterval(-2 * 86_400), waist: 33)

        let series = ProgressCharts.bodyweightOverTime(in: [newer, weightless, older])

        XCTAssertEqual(series.map(\.value), [183, 181], "Weightless snapshots excluded, ascending by date")
    }

    // MARK: - Empty inputs

    func testEmptyInputsProduceEmptySeries() {
        let exercise = makeExercise()
        XCTAssertTrue(ProgressCharts.estimatedOneRepMaxOverTime(for: exercise, in: []).isEmpty)
        XCTAssertTrue(ProgressCharts.volumePerSession(in: []).isEmpty)
        XCTAssertTrue(ProgressCharts.bodyweightOverTime(in: []).isEmpty)
    }
}
