import Foundation

/// Read-only derivation of achievement badges from workout history.
///
/// Like ``WorkoutStreaks`` and ``PersonalRecordsService`` this is a pure
/// computation over already-fetched models — it never mutates the store and
/// introduces no persisted `@Model`. Badges are recomputed on the fly from the
/// finished-workout count, the best streak, and whether any personal record
/// exists, so they always reflect current history without a cache to keep in
/// sync.
///
/// The only thing worth persisting is which earned badges the user has already
/// *seen*, so a freshly earned one can be flagged "new" — that lives in
/// ``AchievementsSeenStore`` (UserDefaults), never in the model store.
enum Achievements {

    /// How a badge is grouped in the UI.
    enum Category: String, CaseIterable {
        case milestone
        case streak
        case record

        /// Section title shown above the badges in this category.
        var title: String {
            switch self {
            case .milestone: return "Milestones"
            case .streak: return "Streaks"
            case .record: return "Records"
            }
        }
    }

    /// A single badge and the user's progress toward it, derived live from
    /// history. Never earned twice — `isEarned` simply reflects whether the
    /// current history clears the bar.
    struct Achievement: Identifiable, Equatable {
        /// Stable key (e.g. `"workouts_10"`) used for identity and for tracking
        /// which badges have been seen. Never localized — it is not shown.
        let id: String
        let category: Category
        let title: String
        /// One-line explanation of what earns the badge.
        let detail: String
        let systemImage: String
        let isEarned: Bool
        /// Fraction of the way to earning the badge, `0...1` (always `1` once
        /// earned). Drives the progress ring on unearned tiles.
        let progress: Double
        /// Human-readable progress toward the target while unearned (e.g.
        /// `"7 / 10"`), or `nil` for earned/binary badges.
        let progressText: String?
    }

    /// All badges, in display order (grouped by category). `hasPersonalRecord`
    /// comes from the persisted ``PersonalRecord`` cache so the record badge
    /// tracks the same records the Records tab shows.
    static func all(
        in workouts: [Workout],
        hasPersonalRecord: Bool,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [Achievement] {
        let finishedCount = workouts.lazy.filter(\.isFinished).count
        let bestStreak = WorkoutStreaks.streaks(in: workouts, today: today, calendar: calendar).best

        let milestones: [Achievement] = workoutMilestones.map { milestone in
            countAchievement(
                id: "workouts_\(milestone.target)",
                category: .milestone,
                title: milestone.title,
                unit: "workout",
                systemImage: milestone.systemImage,
                count: finishedCount,
                target: milestone.target
            )
        }

        let streaks: [Achievement] = streakMilestones.map { milestone in
            countAchievement(
                id: "streak_\(milestone.target)",
                category: .streak,
                title: milestone.title,
                unit: "day",
                systemImage: "flame.fill",
                count: bestStreak,
                target: milestone.target
            )
        }

        let record = Achievement(
            id: "record_first",
            category: .record,
            title: "Personal Record",
            detail: "Set your first personal record.",
            systemImage: "trophy.fill",
            isEarned: hasPersonalRecord,
            progress: hasPersonalRecord ? 1 : 0,
            progressText: nil
        )

        return milestones + streaks + [record]
    }

    /// Convenience: the ids of every currently-earned badge.
    static func earnedIDs(
        in workouts: [Workout],
        hasPersonalRecord: Bool,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Set<String> {
        Set(
            all(in: workouts, hasPersonalRecord: hasPersonalRecord, today: today, calendar: calendar)
                .filter(\.isEarned)
                .map(\.id)
        )
    }

    // MARK: - Definitions

    private struct Milestone {
        let target: Int
        let title: String
        let systemImage: String
    }

    /// Finished-workout count thresholds.
    private static let workoutMilestones: [Milestone] = [
        Milestone(target: 1, title: "First Workout", systemImage: "figure.strengthtraining.traditional"),
        Milestone(target: 10, title: "10 Workouts", systemImage: "10.circle.fill"),
        Milestone(target: 25, title: "25 Workouts", systemImage: "25.circle.fill"),
        Milestone(target: 50, title: "50 Workouts", systemImage: "50.circle.fill"),
        Milestone(target: 100, title: "Century", systemImage: "crown.fill"),
    ]

    /// Best-streak (consecutive training days) thresholds.
    private static let streakMilestones: [Milestone] = [
        Milestone(target: 7, title: "7-Day Streak", systemImage: "flame.fill"),
        Milestone(target: 30, title: "30-Day Streak", systemImage: "flame.fill"),
    ]

    /// Builds a threshold badge whose progress is `count / target`.
    private static func countAchievement(
        id: String,
        category: Category,
        title: String,
        unit: String,
        systemImage: String,
        count: Int,
        target: Int
    ) -> Achievement {
        let isEarned = count >= target
        let plural = target == 1 ? unit : "\(unit)s"
        return Achievement(
            id: id,
            category: category,
            title: title,
            detail: "Log \(target) \(plural).",
            systemImage: systemImage,
            isEarned: isEarned,
            progress: target > 0 ? min(1, Double(count) / Double(target)) : 1,
            progressText: isEarned ? nil : "\(min(count, target)) / \(target)"
        )
    }
}

/// Remembers which earned badges the user has already seen, so the
/// Achievements screen can flag freshly earned ones as "new".
///
/// This is the only persisted piece of the achievements feature, and it is
/// intentionally kept out of the SwiftData store (per ba-oy0.3): a small set of
/// stable ids in `UserDefaults`. Losing it only costs a stray "new" badge, so
/// no migration or CloudKit concerns apply.
enum AchievementsSeenStore {
    static let key = "achievements.seenEarnedIDs"

    /// The ids the user has acknowledged so far.
    static func seenIDs(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    /// Records `ids` as seen, replacing the stored set. Sorted for a stable,
    /// diff-friendly representation on disk.
    static func markSeen(_ ids: Set<String>, _ defaults: UserDefaults = .standard) {
        defaults.set(ids.sorted(), forKey: key)
    }

    /// The earned ids not yet acknowledged, then marks them seen so they are
    /// "new" exactly once. Returns the set the caller should highlight.
    @discardableResult
    static func consumeNewlyEarned(
        _ earned: Set<String>,
        _ defaults: UserDefaults = .standard
    ) -> Set<String> {
        let fresh = earned.subtracting(seenIDs(defaults))
        markSeen(earned, defaults)
        return fresh
    }
}
