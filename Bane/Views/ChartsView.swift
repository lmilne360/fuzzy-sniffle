import Charts
import SwiftData
import SwiftUI

/// The Charts tab: progress over time rendered with Swift Charts.
///
/// Three read-only series driven by ``ProgressCharts``:
/// - estimated 1RM over time for a chosen exercise,
/// - total working volume per session,
/// - bodyweight over time.
///
/// The view only reads logged workouts and body measurements; it never mutates
/// the store. The 1RM series is picked per exercise via a menu, defaulting to the
/// first exercise that has any recorded history.
struct ChartsView: View {
    @Query(sort: \Workout.date) private var workouts: [Workout]
    @Query(sort: \BodyMeasurement.date) private var measurements: [BodyMeasurement]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    /// The exercise whose estimated-1RM trend is charted. `nil` until resolved to
    /// a default on first appearance (the first exercise with history).
    @State private var selectedExercise: Exercise?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                oneRepMaxCard
                volumeCard
                bodyweightCard
            }
            .padding()
        }
        .navigationTitle("Charts")
        .background(Color(.systemGroupedBackground))
        .onAppear(perform: resolveDefaultExercise)
    }

    // MARK: Estimated 1RM

    private var oneRepMaxCard: some View {
        ChartCard(title: "Estimated 1RM", systemImage: "chart.line.uptrend.xyaxis") {
            if chartableExercises.isEmpty {
                emptyState("Log a working set to chart your estimated one-rep max.")
            } else {
                exercisePicker
                let series = oneRepMaxSeries
                if series.isEmpty {
                    emptyState("No sets logged yet for this exercise.")
                } else {
                    lineChart(series, unitLabel: "Est. 1RM")
                }
            }
        }
    }

    private var exercisePicker: some View {
        Picker("Exercise", selection: $selectedExercise) {
            ForEach(chartableExercises) { exercise in
                Text(exercise.name).tag(Optional(exercise))
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Volume per session

    private var volumeCard: some View {
        ChartCard(title: "Volume per Session", systemImage: "square.stack.3d.up") {
            let series = ProgressCharts.volumePerSession(in: workouts)
            if series.isEmpty {
                emptyState("Finish a workout with logged sets to see session volume.")
            } else {
                Chart(series) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Volume", point.value)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartYAxisLabel("Volume")
                .frame(height: 220)
            }
        }
    }

    // MARK: Bodyweight

    private var bodyweightCard: some View {
        ChartCard(title: "Bodyweight", systemImage: "scalemass") {
            let series = ProgressCharts.bodyweightOverTime(in: measurements)
            if series.isEmpty {
                emptyState("Record a bodyweight measurement on the Body tab to chart it.")
            } else {
                lineChart(series, unitLabel: "Weight")
            }
        }
    }

    // MARK: Shared chart building

    /// A date-vs-value line with points, used by the 1RM and bodyweight series.
    private func lineChart(_ series: [ProgressCharts.DataPoint], unitLabel: String) -> some View {
        Chart(series) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value(unitLabel, point.value)
            )
            .foregroundStyle(Color.accentColor)
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", point.date),
                y: .value(unitLabel, point.value)
            )
            .foregroundStyle(Color.accentColor)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxisLabel(unitLabel)
        .frame(height: 220)
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    // MARK: Derived data

    /// Exercises that have at least one record-eligible set, so the picker only
    /// offers exercises the 1RM chart can actually plot.
    private var chartableExercises: [Exercise] {
        exercises.filter { !PersonalRecordsService.candidates(for: $0, in: workouts).isEmpty }
    }

    /// The estimated-1RM series for the currently selected exercise (empty when
    /// none is selected yet).
    private var oneRepMaxSeries: [ProgressCharts.DataPoint] {
        guard let selectedExercise else { return [] }
        return ProgressCharts.estimatedOneRepMaxOverTime(for: selectedExercise, in: workouts)
    }

    /// Defaults the picker to the first exercise with history, and clears a stale
    /// selection if its exercise no longer has any chartable sets.
    private func resolveDefaultExercise() {
        let chartable = chartableExercises
        if let selectedExercise, chartable.contains(where: { $0.id == selectedExercise.id }) {
            return
        }
        selectedExercise = chartable.first
    }
}

// MARK: - Card container

/// A titled rounded container matching the Muscles/Body tab card styling, so the
/// three charts read as a consistent stack.
private struct ChartCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    let context = container.mainContext
    ExerciseLibrary.seedIfNeeded(in: context)

    let exercises = Array((try? context.fetch(FetchDescriptor<Exercise>()))?.prefix(4) ?? [])
    // Fabricate a progression across several days so every chart has data.
    for dayOffset in [28, 21, 14, 7, 1] {
        let day = Date.now.addingTimeInterval(Double(-dayOffset) * 86_400)
        let workout = Workout(date: day, startedAt: day, finishedAt: day.addingTimeInterval(3600))
        context.insert(workout)
        for (index, exercise) in exercises.enumerated() {
            let we = WorkoutExercise(order: index, exercise: exercise)
            we.workout = workout
            let progression = Double(30 - dayOffset)
            we.sets = (0..<3).map { setIndex in
                SetEntry(
                    order: setIndex,
                    reps: 5 + setIndex,
                    weight: Double(95 + index * 20) + progression,
                    completed: true
                )
            }
            for set in we.sets { set.workoutExercise = we }
            workout.exercises.append(we)
        }

        context.insert(BodyMeasurement(date: day, weight: 185 - Double(dayOffset) * 0.1))
    }

    return NavigationStack {
        ChartsView()
    }
    .modelContainer(container)
}
