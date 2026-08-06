import SwiftData
import SwiftUI

/// The Muscles tab: a body heat map of recent training volume.
///
/// Aggregates working volume by each exercise's primary muscle over a rolling
/// window (see ``MuscleHeatMap``) and paints front and back body diagrams,
/// tinting each muscle region by how much it was trained relative to the most
/// worked muscle. A ranked breakdown and an "undertrained" hint follow. The
/// view is read-only over the model — it only reads logged workouts.
struct MuscleHeatMapView: View {
    @Environment(\.banePalette) private var palette
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @State private var window: HeatMapWindow = .month

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                windowPicker

                if trainedVolumes.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    bodyDiagrams
                    HeatLegend()
                    breakdown
                    undertrained
                }
            }
            .padding()
        }
        .navigationTitle("Muscles")
        .background(palette.bg)
    }

    // MARK: Sections

    private var windowPicker: some View {
        Picker("Window", selection: $window) {
            ForEach(HeatMapWindow.allCases) { window in
                Text(window.displayName).tag(window)
            }
        }
        .pickerStyle(.segmented)
    }

    private var bodyDiagrams: some View {
        HStack(alignment: .top, spacing: 12) {
            labeledBody("Front", regions: BodyDiagram.frontRegions)
            labeledBody("Back", regions: BodyDiagram.backRegions)
        }
    }

    private func labeledBody(_ title: String, regions: [BodyRegion]) -> some View {
        VStack(spacing: 8) {
            BodyDiagram(regions: regions, intensity: intensity(for:))
                .frame(maxWidth: .infinity)
                .aspectRatio(0.5, contentMode: .fit)
            Text(title)
                .font(BaneFont.mono(12, weight: .medium))
                .foregroundStyle(palette.text3)
        }
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume by Muscle")
                .baneHeading(13)
                .foregroundStyle(palette.text)

            ForEach(trainedVolumes) { entry in
                MuscleVolumeRow(
                    entry: entry,
                    fraction: maxVolume > 0 ? entry.volume / maxVolume : 0
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var undertrained: some View {
        let names = untrainedMuscleNames
        if !names.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Not trained this window", systemImage: "moon.zzz")
                    .font(BaneFont.mono(12, weight: .medium))
                    .foregroundStyle(palette.text3)
                Text(names.joined(separator: ", "))
                    .font(BaneFont.mono(11))
                    .foregroundStyle(palette.text3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(palette.line, lineWidth: 1)
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Training Volume", systemImage: "flame")
        } description: {
            Text("Finish a workout with logged sets to see which muscles you've been training.")
        }
    }

    // MARK: Derived data

    /// Muscles trained in the window, ordered by descending volume.
    private var trainedVolumes: [MuscleVolume] {
        MuscleHeatMap.volumes(in: workouts, since: window.startDate())
            .sorted { $0.volume > $1.volume }
    }

    private var maxVolume: Double {
        trainedVolumes.map(\.volume).max() ?? 0
    }

    /// Volume keyed by muscle for O(1) lookup while painting regions.
    private var volumeByMuscle: [Muscle: Double] {
        Dictionary(uniqueKeysWithValues: trainedVolumes.map { ($0.muscle, $0.volume) })
    }

    /// Normalized 0...1 intensity for a muscle relative to the most trained one.
    private func intensity(for muscle: Muscle) -> Double {
        guard maxVolume > 0, let volume = volumeByMuscle[muscle] else { return 0 }
        return volume / maxVolume
    }

    /// Display names of muscles that have a body region but saw no volume, so
    /// the user can spot gaps. Only muscles actually rendered on the diagrams
    /// are considered (skips `.fullBody` / `.other`).
    private var untrainedMuscleNames: [String] {
        let mapped = Set((BodyDiagram.frontRegions + BodyDiagram.backRegions).map(\.muscle))
        let trained = Set(trainedVolumes.map(\.muscle))
        return Muscle.allCases
            .filter { mapped.contains($0) && !trained.contains($0) }
            .map(\.displayName)
    }
}

// MARK: - Breakdown row

/// One muscle in the ranked breakdown: a heat swatch, its name and set count,
/// a proportional volume bar, and the whole-number volume total.
private struct MuscleVolumeRow: View {
    let entry: MuscleVolume
    /// Share of the top muscle's volume, driving the bar width (0...1).
    let fraction: Double

    /// The unit the volume total is shown in; storage stays pounds.
    @AppStorage(WeightPreferences.unitKey) private var weightUnit = WeightPreferences.fallback
    @Environment(\.banePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(MuscleHeatMap.heatColor(for: fraction))
                    .frame(width: 14, height: 14)
                Text(entry.muscle.displayName)
                    .font(BaneFont.body(14))
                    .foregroundStyle(palette.text)
                Spacer()
                Text("\(WeightFormat.volume(entry.volume, in: weightUnit)) vol")
                    .font(BaneFont.mono(13))
                    .foregroundStyle(palette.text2)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.surface3)
                    Capsule()
                        .fill(MuscleHeatMap.heatColor(for: fraction))
                        .frame(width: max(4, geometry.size.width * fraction))
                }
            }
            .frame(height: 6)

            Text("\(entry.setCount) set\(entry.setCount == 1 ? "" : "s")")
                .font(BaneFont.mono(10))
                .foregroundStyle(palette.text3)
        }
    }
}

// MARK: - Legend

/// A horizontal gradient legend explaining the low-to-high heat scale.
private struct HeatLegend: View {
    @Environment(\.banePalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Text("Less")
                .font(BaneFont.mono(10))
                .foregroundStyle(palette.text3)
            LinearGradient(
                colors: stride(from: 0.0, through: 1.0, by: 0.1)
                    .map { MuscleHeatMap.heatColor(for: $0) },
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 8)
            .clipShape(Capsule())
            Text("More")
                .font(BaneFont.mono(10))
                .foregroundStyle(palette.text3)
        }
    }
}

#Preview {
    let container = Persistence.inMemoryContainer()
    let context = container.mainContext
    ExerciseLibrary.seedIfNeeded(in: context)

    let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
    // Fabricate a couple of finished workouts so the preview shows real heat.
    for dayOffset in [1, 3, 6] {
        let workout = Workout(
            date: .now.addingTimeInterval(Double(-dayOffset) * 86_400),
            startedAt: .now.addingTimeInterval(Double(-dayOffset) * 86_400),
            finishedAt: .now.addingTimeInterval(Double(-dayOffset) * 86_400 + 3600)
        )
        context.insert(workout)
        for (index, exercise) in exercises.prefix(5).enumerated() {
            let we = WorkoutExercise(order: index, exercise: exercise)
            we.workout = workout
            we.sets = (0..<3).map { setIndex in
                SetEntry(order: setIndex, reps: 8 + setIndex, weight: Double(50 + index * 20), completed: true)
            }
            for set in we.sets { set.workoutExercise = we }
            workout.exercises.append(we)
        }
    }

    return NavigationStack {
        MuscleHeatMapView()
    }
    .modelContainer(container)
}
