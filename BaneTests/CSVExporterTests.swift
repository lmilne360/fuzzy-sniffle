import XCTest
import SwiftData
@testable import Bane

/// Unit tests for ``CSVExporter`` — the pure CSV serialization behind the data
/// export / share-sheet feature (ba-07l.10).
///
/// The exporter is a pure function over models, so these build small in-memory
/// object graphs and assert the produced text row-by-row. Tests run on the main
/// actor to match the rest of the suite.
@MainActor
final class CSVExporterTests: XCTestCase {

    private let calendar = Calendar.current

    private func makeExercise(_ name: String = "Bench Press") -> Exercise {
        Exercise(name: name, category: .chest, primaryMuscle: .chest, equipment: .barbell)
    }

    /// A finished workout on `date` with one exercise and the given sets.
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

    // MARK: - Field encoding

    func testEscapeLeavesPlainFieldsUntouched() {
        XCTAssertEqual(CSVExporter.escape("Bench Press"), "Bench Press")
    }

    func testEscapeQuotesFieldsWithCommaQuoteOrNewline() {
        XCTAssertEqual(CSVExporter.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVExporter.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSVExporter.escape("line1\nline2"), "\"line1\nline2\"")
    }

    func testNumberDropsDecimalForWholeValues() {
        XCTAssertEqual(CSVExporter.number(100), "100")
        XCTAssertEqual(CSVExporter.number(102.5), "102.50")
    }

    // MARK: - Workouts CSV

    func testWorkoutsCSVHasHeaderOnlyWhenEmpty() {
        let csv = CSVExporter.workoutsCSV(from: [])
        XCTAssertEqual(
            csv,
            "Date,Workout,Exercise,Category,Primary Muscle,Equipment,Set,Reps,Weight (lb),RPE,Warmup,Completed,Volume (lb),Superset"
        )
    }

    func testWorkoutsCSVEmitsOneRowPerSetWithVolumeAndFlags() {
        let exercise = makeExercise()
        let day = calendar.startOfDay(for: .now)
        let workout = finishedWorkout(on: day, exercise: exercise, sets: [
            (reps: 5, weight: 45, warmup: true),
            (reps: 5, weight: 100, warmup: false),
        ])

        let lines = CSVExporter.workoutsCSV(from: [workout]).split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.count, 3) // header + 2 sets

        // Warm-up set: Set 1, warmup Yes, volume still reps × weight.
        XCTAssertTrue(lines[1].hasSuffix("Bench Press,Chest,Chest,Barbell,1,5,45,,Yes,Yes,225,"))
        // Working set: Set 2, warmup No.
        XCTAssertTrue(lines[2].hasSuffix("Bench Press,Chest,Chest,Barbell,2,5,100,,No,Yes,500,"))
    }

    func testWorkoutsCSVOrdersByWorkoutDateAscending() {
        let exercise = makeExercise()
        let earlier = calendar.startOfDay(for: .now.addingTimeInterval(-7 * 86_400))
        let later = calendar.startOfDay(for: .now)
        let w1 = finishedWorkout(on: later, exercise: exercise, sets: [(reps: 1, weight: 200, warmup: false)])
        let w2 = finishedWorkout(on: earlier, exercise: exercise, sets: [(reps: 1, weight: 100, warmup: false)])

        let lines = CSVExporter.workoutsCSV(from: [w1, w2]).split(separator: "\n")
        // Earlier workout (weight 100) comes before the later one (weight 200).
        XCTAssertTrue(lines[1].contains(",1,100,"))
        XCTAssertTrue(lines[2].contains(",1,200,"))
    }

    func testWorkoutsCSVLabelsSupersetGroups() {
        let a = makeExercise("A")
        let b = makeExercise("B")
        let group = UUID()
        let workout = Workout(date: .now, startedAt: .now, finishedAt: .now)
        let we1 = WorkoutExercise(order: 0, exercise: a, supersetGroup: group)
        let we2 = WorkoutExercise(order: 1, exercise: b, supersetGroup: group)
        for we in [we1, we2] {
            we.workout = workout
            let set = SetEntry(order: 0, reps: 5, weight: 50)
            set.workoutExercise = we
            we.sets = [set]
        }
        workout.exercises = [we1, we2]

        let lines = CSVExporter.workoutsCSV(from: [workout]).split(separator: "\n")
        // Both exercises share group -> both labeled "A".
        XCTAssertTrue(lines[1].hasSuffix(",A"))
        XCTAssertTrue(lines[2].hasSuffix(",A"))
    }

    // MARK: - Records CSV

    func testRecordsCSVHasHeaderOnlyWhenNoHistory() {
        let exercise = makeExercise()
        let csv = CSVExporter.recordsCSV(for: [exercise], in: [])
        XCTAssertEqual(csv, "Exercise,Metric,Value (lb),Reps,Weight (lb),Achieved On")
    }

    func testRecordsCSVEmitsARowPerMetric() {
        let exercise = makeExercise()
        let workout = finishedWorkout(on: calendar.startOfDay(for: .now), exercise: exercise, sets: [
            (reps: 5, weight: 100, warmup: false),
        ])

        let lines = CSVExporter.recordsCSV(for: [exercise], in: [workout]).split(separator: "\n")
        // Header + one row for each PRMetric.
        XCTAssertEqual(lines.count, 1 + PRMetric.allCases.count)
        XCTAssertTrue(lines.dropFirst().allSatisfy { $0.hasPrefix("Bench Press,") })
    }
}
