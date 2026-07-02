import XCTest
import SwiftData
@testable import Bane

/// Unit tests for ``Achievements`` and ``AchievementsSeenStore`` — the pure
/// derivation behind the Achievements screen (ba-oy0.3).
///
/// Badges come purely from finished-workout history plus a "has personal
/// record" flag, so tests pin `today` and build workouts at fixed day offsets.
@MainActor
final class AchievementsTests: XCTestCase {

    private let calendar = Calendar.current

    /// A finished workout `dayOffset` days before `reference` (0 == today).
    private func finished(daysAgo dayOffset: Int, from reference: Date) -> Workout {
        let day = calendar.date(byAdding: .day, value: -dayOffset, to: reference)!
        return Workout(date: day, startedAt: day, finishedAt: day.addingTimeInterval(3600))
    }

    private func badge(_ id: String, in achievements: [Achievements.Achievement]) -> Achievements.Achievement {
        achievements.first { $0.id == id }!
    }

    // MARK: - Milestones

    /// No history → nothing earned, and count badges show 0-toward-target.
    func testEmptyHistoryEarnsNothing() {
        let achievements = Achievements.all(in: [], hasPersonalRecord: false, today: .now, calendar: calendar)

        XCTAssertFalse(achievements.contains { $0.isEarned })
        let first = badge("workouts_1", in: achievements)
        XCTAssertEqual(first.progressText, "0 / 1")
        XCTAssertEqual(first.progress, 0)
    }

    /// A single finished workout earns "First Workout" but not the 10-workout
    /// milestone, which reports partial progress.
    func testFirstWorkoutEarnedButNotTen() {
        let today = calendar.startOfDay(for: .now)
        let achievements = Achievements.all(
            in: [finished(daysAgo: 0, from: today)],
            hasPersonalRecord: false,
            today: today,
            calendar: calendar
        )

        XCTAssertTrue(badge("workouts_1", in: achievements).isEarned)

        let ten = badge("workouts_10", in: achievements)
        XCTAssertFalse(ten.isEarned)
        XCTAssertEqual(ten.progressText, "1 / 10")
        XCTAssertEqual(ten.progress, 0.1, accuracy: 0.0001)
    }

    /// Unfinished workouts don't count toward milestones.
    func testUnfinishedWorkoutsDoNotCount() {
        let today = calendar.startOfDay(for: .now)
        let inProgress = Workout(date: today, startedAt: today)

        let achievements = Achievements.all(in: [inProgress], hasPersonalRecord: false, today: today, calendar: calendar)

        XCTAssertFalse(badge("workouts_1", in: achievements).isEarned)
    }

    /// Earned count badges clamp progress at 1 and drop the progress text.
    func testEarnedMilestoneClampsProgress() {
        let today = calendar.startOfDay(for: .now)
        // 12 distinct finished days clears the 10-workout milestone.
        let workouts = (0..<12).map { finished(daysAgo: $0, from: today) }

        let ten = badge("workouts_10", in: Achievements.all(
            in: workouts, hasPersonalRecord: false, today: today, calendar: calendar
        ))

        XCTAssertTrue(ten.isEarned)
        XCTAssertEqual(ten.progress, 1)
        XCTAssertNil(ten.progressText)
    }

    // MARK: - Streaks

    /// A 7-day best streak earns the 7-day badge but not the 30-day one.
    func testSevenDayStreakEarned() {
        let today = calendar.startOfDay(for: .now)
        let workouts = (0..<7).map { finished(daysAgo: $0, from: today) }

        let achievements = Achievements.all(
            in: workouts, hasPersonalRecord: false, today: today, calendar: calendar
        )

        XCTAssertTrue(badge("streak_7", in: achievements).isEarned)
        XCTAssertFalse(badge("streak_30", in: achievements).isEarned)
    }

    // MARK: - Records

    /// The record badge tracks the passed-in flag.
    func testPersonalRecordBadgeFollowsFlag() {
        let earned = badge("record_first", in: Achievements.all(in: [], hasPersonalRecord: true, calendar: calendar))
        XCTAssertTrue(earned.isEarned)

        let unearned = badge("record_first", in: Achievements.all(in: [], hasPersonalRecord: false, calendar: calendar))
        XCTAssertFalse(unearned.isEarned)
    }

    // MARK: - Seen store

    /// `consumeNewlyEarned` returns only the ids not previously seen, then marks
    /// everything seen so a second call reports nothing new.
    func testSeenStoreReportsFreshlyEarnedOnce() {
        let defaults = UserDefaults(suiteName: "achievements.test.\(UUID().uuidString)")!

        let first = AchievementsSeenStore.consumeNewlyEarned(["workouts_1"], defaults)
        XCTAssertEqual(first, ["workouts_1"])

        // Same set again → nothing new.
        XCTAssertTrue(AchievementsSeenStore.consumeNewlyEarned(["workouts_1"], defaults).isEmpty)

        // A newly earned badge appears → only that one is fresh.
        let second = AchievementsSeenStore.consumeNewlyEarned(["workouts_1", "workouts_10"], defaults)
        XCTAssertEqual(second, ["workouts_10"])
    }
}
