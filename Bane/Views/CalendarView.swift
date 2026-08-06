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
    @Environment(\.banePalette) private var palette
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
        .background(palette.bg)
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

    // MARK: Month grid

    private var calendarCard: some View {
        VStack(spacing: 16) {
            monthHeader
            weekdayHeader
            monthGrid
        }
        .padding()
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.line, lineWidth: 1)
        )
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(palette.accent)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(visibleMonth, format: .dateTime.month(.wide).year())
                .baneHeading(15)
                .foregroundStyle(palette.text)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(palette.accent)
            }
            .accessibilityLabel("Next month")
            .disabled(isDisplayingCurrentMonth)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(BaneFont.mono(11, weight: .semibold))
                    .foregroundStyle(palette.text3)
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
            .font(BaneFont.mono(15))
            .foregroundStyle(isTrained ? palette.onAccent : palette.text)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background {
                if isTrained {
                    Circle().fill(palette.accent)
                }
            }
            .overlay {
                if isToday {
                    Circle().strokeBorder(palette.accent, lineWidth: isTrained ? 0 : 1.5)
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
