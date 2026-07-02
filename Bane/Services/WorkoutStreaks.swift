import Foundation

/// Read-only aggregation of workout history into the training-day set and streak
/// counts the Calendar screen shows. Like ``ProgressCharts`` this is a pure
/// computation over already-fetched models — it never mutates the store — so it
/// is equally usable from views, previews, and tests.
///
/// A "training day" is any calendar day on which at least one workout was
/// *finished*; in-progress sessions don't count toward the calendar or streaks.
/// Multiple sessions on the same day collapse to a single training day.
enum WorkoutStreaks {

    /// Current and longest run of consecutive training days.
    struct Streaks: Equatable {
        /// Length of the run of consecutive days ending on the most recent
        /// training day — but only while that day is today or yesterday, so an
        /// unbroken habit still reads as "current" before today's session. `0`
        /// once a full rest day has elapsed with no workout.
        var current: Int
        /// The longest run of consecutive training days ever recorded.
        var best: Int

        static let none = Streaks(current: 0, best: 0)
    }

    /// The distinct calendar days (normalized to `startOfDay`) on which at least
    /// one workout was finished.
    static func trainingDays(
        in workouts: [Workout],
        calendar: Calendar = .current
    ) -> Set<Date> {
        var days: Set<Date> = []
        for workout in workouts where workout.isFinished {
            days.insert(calendar.startOfDay(for: workout.date))
        }
        return days
    }

    /// Current and best streaks over `workouts`, measured in consecutive calendar
    /// days relative to `today`.
    ///
    /// `best` is the longest run of back-to-back training days anywhere in
    /// history. `current` is the run ending on the most recent training day, kept
    /// "live" only while that day is today or yesterday — otherwise it resets to
    /// `0` because the habit has lapsed.
    static func streaks(
        in workouts: [Workout],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Streaks {
        let days = trainingDays(in: workouts, calendar: calendar)
        guard !days.isEmpty else { return .none }

        let sorted = days.sorted()

        // Longest run of consecutive days anywhere in history.
        var best = 1
        var run = 1
        for index in 1..<sorted.count {
            if calendar.dateComponents([.day], from: sorted[index - 1], to: sorted[index]).day == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }

        // Current streak: walk backward from the most recent training day, but
        // only count it if the habit is still live (last workout today/yesterday).
        let startOfToday = calendar.startOfDay(for: today)
        guard let mostRecent = sorted.last else { return Streaks(current: 0, best: best) }
        let daysSinceLast = calendar.dateComponents([.day], from: mostRecent, to: startOfToday).day ?? 0

        var current = 0
        if daysSinceLast <= 1 {
            current = 1
            var index = sorted.count - 1
            while index > 0,
                  calendar.dateComponents([.day], from: sorted[index - 1], to: sorted[index]).day == 1 {
                current += 1
                index -= 1
            }
        }

        return Streaks(current: current, best: best)
    }
}
