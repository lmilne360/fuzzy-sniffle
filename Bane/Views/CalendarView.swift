import SwiftData
import SwiftUI

/// The Calendar tab: a month grid highlighting the days you trained, plus your
/// current and best workout streaks.
///
/// Purely a read-only lens over finished workout history — it computes training
/// days and streaks via ``WorkoutStreaks`` and never mutates the store. Users
/// page between months with the chevrons; days with a finished workout are
/// filled with the accent color, and today is ringed.
struct CalendarView: View {
    @Query(sort: \Workout.date) private var workouts: [Workout]

    /// The first day of the month currently displayed. Defaults to this month on
    /// first appearance.
    @State private var visibleMonth = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                streakCard
                calendarCard
            }
            .padding()
        }
        .navigationTitle("Calendar")
        .background(Color(.systemGroupedBackground))
        .overlay {
            if trainingDays.isEmpty {
                emptyState
            }
        }
        .onAppear {
            visibleMonth = startOfMonth(for: .now)
        }
    }

    // MARK: Streak summary

    private var streakCard: some View {
        let streaks = WorkoutStreaks.streaks(in: workouts, calendar: calendar)
        return HStack(spacing: 12) {
            streakStat(
                title: "Current Streak",
                value: streaks.current,
                systemImage: "flame.fill",
                tint: streaks.current > 0 ? .orange : .secondary
            )
            streakStat(
                title: "Best Streak",
                value: streaks.best,
                systemImage: "trophy.fill",
                tint: streaks.best > 0 ? .yellow : .secondary
            )
        }
    }

    private func streakStat(title: String, value: Int, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title.weight(.bold))
                .monospacedDigit()
            Text(value == 1 ? "day" : "days")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Month grid

    private var calendarCard: some View {
        VStack(spacing: 16) {
            monthHeader
            weekdayHeader
            monthGrid
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(visibleMonth, format: .dateTime.month(.wide).year())
                .font(.headline)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .accessibilityLabel("Next month")
            .disabled(isDisplayingCurrentMonth)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isTrained = trainingDays.contains(calendar.startOfDay(for: day))
        let isToday = calendar.isDateInToday(day)
        return Text("\(calendar.component(.day, from: day))")
            .font(.callout)
            .monospacedDigit()
            .foregroundStyle(isTrained ? Color.white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background {
                if isTrained {
                    Circle().fill(Color.accentColor)
                }
            }
            .overlay {
                if isToday {
                    Circle().strokeBorder(Color.accentColor, lineWidth: isTrained ? 0 : 1.5)
                }
            }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Workouts Yet", systemImage: "calendar")
        } description: {
            Text("Finish a workout and the day lights up here — build a streak.")
        }
    }

    // MARK: Derived data

    private var trainingDays: Set<Date> {
        WorkoutStreaks.trainingDays(in: workouts, calendar: calendar)
    }

    /// Localized one-letter weekday symbols, rotated to the calendar's first
    /// weekday so the header lines up with the grid.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The cells for the visible month: leading `nil`s to pad to the first
    /// weekday, then one entry per day of the month.
    private var gridDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: visibleMonth) else { return [] }
        let firstOfMonth = startOfMonth(for: visibleMonth)
        let leadingBlanks = (calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for dayOffset in range {
            if let day = calendar.date(byAdding: .day, value: dayOffset - 1, to: firstOfMonth) {
                cells.append(day)
            }
        }
        return cells
    }

    private var isDisplayingCurrentMonth: Bool {
        calendar.isDate(visibleMonth, equalTo: .now, toGranularity: .month)
    }

    // MARK: Month navigation

    private func startOfMonth(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func shiftMonth(by delta: Int) {
        if let shifted = calendar.date(byAdding: .month, value: delta, to: visibleMonth) {
            visibleMonth = startOfMonth(for: shifted)
        }
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    let context = container.mainContext

    // Fabricate a streak plus scattered earlier days so the grid has data.
    for dayOffset in [0, 1, 2, 3, 7, 9, 14, 15, 16, 40] {
        let day = Calendar.current.date(byAdding: .day, value: -dayOffset, to: .now)!
        let workout = Workout(date: day, startedAt: day, finishedAt: day.addingTimeInterval(3600))
        context.insert(workout)
    }

    return NavigationStack {
        CalendarView()
    }
    .modelContainer(container)
}
