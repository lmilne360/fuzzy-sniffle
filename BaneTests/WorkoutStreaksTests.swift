import XCTest
import SwiftData
@testable import Bane

/// Unit tests for ``WorkoutStreaks`` — the pure aggregation behind the Calendar
/// tab (ba-oy0.6).
///
/// Streaks are measured in consecutive calendar days, so tests pin `today` and
/// build workouts at fixed day offsets from it. Only finished workouts count,
/// and same-day sessions collapse to one training day.
@MainActor
final class WorkoutStreaksTests: XCTestCase {

    private let calendar = Calendar.current

    /// A finished workout `dayOffset` days before `reference` (0 == today).
    private func finished(daysAgo dayOffset: Int, from reference: Date) -> Workout {
        let day = calendar.date(byAdding: .day, value: -dayOffset, to: reference)!
        return Workout(date: day, startedAt: day, finishedAt: day.addingTimeInterval(3600))
    }

    // MARK: - Training days

    /// Only finished workouts count, and multiple sessions on one day collapse to
    /// a single training day.
    func testTrainingDaysCountFinishedAndCollapseSameDay() {
        let today = calendar.startOfDay(for: .now)
        let morning = today.addingTimeInterval(8 * 3600)
        let evening = today.addingTimeInterval(18 * 3600)

        let am = Workout(date: morning, startedAt: morning, finishedAt: morning.addingTimeInterval(3600))
        let pm = Workout(date: evening, startedAt: evening, finishedAt: evening.addingTimeInterval(3600))
        let inProgress = Workout(date: today.addingTimeInterval(-86_400), startedAt: today)

        let days = WorkoutStreaks.trainingDays(in: [am, pm, inProgress], calendar: calendar)

        XCTAssertEqual(days, [today], "Same-day sessions collapse; unfinished workouts don't count")
    }

    // MARK: - Current streak

    /// Consecutive days ending today read as a live current streak.
    func testCurrentStreakCountsConsecutiveDaysEndingToday() {
        let today = calendar.startOfDay(for: .now)
        let workouts = [0, 1, 2].map { finished(daysAgo: $0, from: today) }

        let streaks = WorkoutStreaks.streaks(in: workouts, today: today, calendar: calendar)

        XCTAssertEqual(streaks.current, 3)
        XCTAssertEqual(streaks.best, 3)
    }

    /// A streak ending yesterday is still live (grace day) so you don't lose it
    /// before today's session.
    func testCurrentStreakStaysLiveWhenLastWorkoutWasYesterday() {
        let today = calendar.startOfDay(for: .now)
        let workouts = [1, 2, 3].map { finished(daysAgo: $0, from: today) }

        let streaks = WorkoutStreaks.streaks(in: workouts, today: today, calendar: calendar)

        XCTAssertEqual(streaks.current, 3, "Ending yesterday is still current")
    }

    /// Once a full rest day has passed (last workout two days ago), the current
    /// streak resets to zero even though the best streak stands.
    func testCurrentStreakResetsAfterLapse() {
        let today = calendar.startOfDay(for: .now)
        let workouts = [2, 3, 4].map { finished(daysAgo: $0, from: today) }

        let streaks = WorkoutStreaks.streaks(in: workouts, today: today, calendar: calendar)

        XCTAssertEqual(streaks.current, 0, "Lapsed more than a day → no current streak")
        XCTAssertEqual(streaks.best, 3)
    }

    // MARK: - Best streak

    /// The best streak is the longest consecutive run anywhere in history, even
    /// when it isn't the most recent one.
    func testBestStreakFindsLongestHistoricalRun() {
        let today = calendar.startOfDay(for: .now)
        // A 4-day run long ago, and a 1-day recent workout.
        let longRun = [20, 21, 22, 23].map { finished(daysAgo: $0, from: today) }
        let recent = [finished(daysAgo: 0, from: today)]

        let streaks = WorkoutStreaks.streaks(in: longRun + recent, today: today, calendar: calendar)

        XCTAssertEqual(streaks.best, 4)
        XCTAssertEqual(streaks.current, 1)
    }

    // MARK: - Empty input

    func testEmptyInputProducesNoStreaks() {
        XCTAssertEqual(WorkoutStreaks.streaks(in: [], today: .now, calendar: calendar), .none)
        XCTAssertTrue(WorkoutStreaks.trainingDays(in: [], calendar: calendar).isEmpty)
    }
}
