import SwiftData
import SwiftUI

/// The Achievements screen: your current/best workout streak plus a wall of
/// badges earned from training history (workout milestones, streak milestones,
/// and your first personal record).
///
/// A read-only lens over finished workouts — badges are derived on the fly via
/// ``Achievements`` and never persisted as models. Freshly earned badges (not
/// seen since last visit) are flagged "New" via ``AchievementsSeenStore``.
struct AchievementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.banePalette) private var palette
    @Query(sort: \Workout.date) private var workouts: [Workout]
    @Query private var records: [PersonalRecord]

    /// Ids of badges earned since the last visit, captured once on appear so the
    /// "New" flag is stable while the screen is open.
    @State private var newlyEarned: Set<String> = []

    private let calendar = Calendar.current

    private var achievements: [Achievements.Achievement] {
        Achievements.all(in: workouts, hasPersonalRecord: !records.isEmpty, calendar: calendar)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                streakCard
                summaryHeader
                ForEach(Achievements.Category.allCases, id: \.self) { category in
                    section(category)
                }
            }
            .padding()
        }
        .navigationTitle("Achievements")
        .background(palette.bg)
        .task { PersonalRecordsService.refresh(in: modelContext) }
        .onAppear {
            let earned = Set(achievements.filter(\.isEarned).map(\.id))
            newlyEarned = AchievementsSeenStore.consumeNewlyEarned(earned)
        }
    }

    // MARK: Streak summary

    private var streakCard: some View {
        let streaks = WorkoutStreaks.streaks(in: workouts, calendar: calendar)
        return HStack(spacing: 12) {
            BaneStatTile(
                label: "Current Streak",
                value: "\(streaks.current)",
                unit: streaks.current == 1 ? "day" : "days"
            )
            BaneStatTile(
                label: "Best Streak",
                value: "\(streaks.best)",
                unit: streaks.best == 1 ? "day" : "days"
            )
        }
    }

    // MARK: Badge sections

    private var summaryHeader: some View {
        let earned = achievements.filter(\.isEarned).count
        return VStack(spacing: 4) {
            Text("\(earned) of \(achievements.count)")
                .font(BaneFont.display(28))
                .foregroundStyle(palette.text)
            Text("badges earned")
                .baneLabel()
                .foregroundStyle(palette.text3)
        }
        .frame(maxWidth: .infinity)
    }

    private func section(_ category: Achievements.Category) -> some View {
        let items = achievements.filter { $0.category == category }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        return VStack(alignment: .leading, spacing: 12) {
            Text(category.title)
                .baneHeading(13)
                .foregroundStyle(palette.text)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { achievement in
                    BadgeTile(achievement: achievement, isNew: newlyEarned.contains(achievement.id))
                }
            }
        }
    }
}

/// A single badge: the icon in an earned/locked state, its title, and either a
/// "New" flag (freshly earned) or a progress hint (still locked).
private struct BadgeTile: View {
    let achievement: Achievements.Achievement
    let isNew: Bool

    @Environment(\.banePalette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isEarned ? palette.accentWash : palette.surface3)
                    .frame(width: 60, height: 60)

                if !achievement.isEarned {
                    Circle()
                        .trim(from: 0, to: achievement.progress)
                        .stroke(palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 60, height: 60)
                }

                Image(systemName: achievement.systemImage)
                    .font(.title2)
                    .foregroundStyle(achievement.isEarned ? palette.accent : palette.text3)
            }

            Text(achievement.title)
                .font(BaneFont.body(12))
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(achievement.isEarned ? palette.text : palette.text3)

            if isNew {
                BaneBadge(text: "New", kind: .solid)
            } else if let progressText = achievement.progressText {
                Text(progressText)
                    .font(BaneFont.mono(10))
                    .foregroundStyle(palette.text3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if achievement.isEarned {
            return "\(achievement.title), earned\(isNew ? ", new" : "")"
        }
        let progress = achievement.progressText.map { ", \($0)" } ?? ""
        return "\(achievement.title), locked. \(achievement.detail)\(progress)"
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    let context = container.mainContext

    // A recent streak plus enough sessions to clear the first milestones.
    for dayOffset in [0, 1, 2, 3, 4, 5, 6, 7, 10, 12, 15, 20] {
        let day = Calendar.current.date(byAdding: .day, value: -dayOffset, to: .now)!
        context.insert(Workout(date: day, startedAt: day, finishedAt: day.addingTimeInterval(3600)))
    }

    return NavigationStack {
        AchievementsView()
    }
    .modelContainer(container)
}
