import Foundation

/// Serializes workout history and personal records into CSV text for the data
/// export / share-sheet feature (ba-07l.10).
///
/// Pure functions over already-fetched models — no store access, no file I/O —
/// so the same logic backs the share sheet, previews, and unit tests. Writing the
/// text to files and presenting the share sheet live in the view layer
/// (see ``DataExportView``).
///
/// Records are recomputed live from history via ``PersonalRecordsService`` rather
/// than read from the persisted ``PersonalRecord`` cache, so an export is correct
/// even if the user has never opened the Records screen to refresh that cache.
///
/// Weight and volume columns are always exported in canonical **pounds**
/// (regardless of the app's display unit) and labeled `(lb)`, so exports stay
/// stable and unambiguous (ba-w6o).
enum CSVExporter {

    // MARK: - Field encoding

    /// Encodes a single field per RFC 4180: a value containing a comma, double
    /// quote, or newline is wrapped in double quotes with embedded quotes doubled.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Formats a unitless numeric value without grouping separators (which would
    /// otherwise inject stray commas): whole numbers render without a decimal
    /// point, everything else with up to two fraction digits.
    static func number(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    /// Stable, sortable calendar-day stamp (`yyyy-MM-dd`) used for date columns.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Joins already-escaped fields into one CSV row.
    private static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    // MARK: - Workouts & sets

    /// One row per logged set across every workout, ordered by workout date then
    /// by the workout's own exercise/set ordering.
    ///
    /// Each row carries the parent workout's date and derived name, the exercise's
    /// library metadata, the set's reps/weight/RPE, its warm-up and completion
    /// flags, its volume (`reps × weight`), and a per-workout superset label
    /// (`A`, `B`, …) so alternating blocks stay identifiable in the flat table.
    static func workoutsCSV(from workouts: [Workout]) -> String {
        let header = row([
            "Date", "Workout", "Exercise", "Category", "Primary Muscle", "Equipment",
            "Set", "Reps", "Weight (lb)", "RPE", "Warmup", "Completed", "Volume (lb)", "Superset",
        ])

        var lines = [header]
        for workout in workouts.sorted(by: { $0.date < $1.date }) {
            let supersetLabels = supersetLabels(for: workout)
            let date = dateFormatter.string(from: workout.date)
            let name = workout.displayName

            for workoutExercise in workout.orderedExercises {
                let exercise = workoutExercise.exercise
                let superset = workoutExercise.supersetGroup.flatMap { supersetLabels[$0] } ?? ""

                for set in workoutExercise.orderedSets {
                    lines.append(row([
                        date,
                        name,
                        exercise?.name ?? "(deleted)",
                        exercise?.category.displayName ?? "",
                        exercise?.primaryMuscle.displayName ?? "",
                        exercise?.equipment.displayName ?? "",
                        String(set.order + 1),
                        String(set.reps),
                        number(set.weight),
                        set.rpe.map(number) ?? "",
                        set.isWarmup ? "Yes" : "No",
                        set.completed ? "Yes" : "No",
                        number(Double(set.reps) * set.weight),
                        superset,
                    ]))
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Assigns each distinct superset group in a workout a short letter label in
    /// the order the groups first appear, so the flat CSV can show `A`/`B`/… for
    /// alternating blocks without leaking raw UUIDs.
    private static func supersetLabels(for workout: Workout) -> [UUID: String] {
        var labels: [UUID: String] = [:]
        var next = 0
        for workoutExercise in workout.orderedExercises {
            guard let group = workoutExercise.supersetGroup, labels[group] == nil else { continue }
            labels[group] = String(UnicodeScalar(UInt8(65 + next % 26)))
            next += 1
        }
        return labels
    }

    // MARK: - Personal records

    /// One row per personal record, computed live from `workouts` for each of
    /// `exercises` (see ``PersonalRecordsService/records(for:in:)``). Rows are
    /// ordered by exercise name, then by ``PRMetric/allCases`` order. Exercises
    /// with no qualifying history contribute no rows.
    static func recordsCSV(for exercises: [Exercise], in workouts: [Workout]) -> String {
        let header = row(["Exercise", "Metric", "Value (lb)", "Reps", "Weight (lb)", "Achieved On"])

        var lines = [header]
        for exercise in exercises.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            for record in PersonalRecordsService.records(for: exercise, in: workouts) {
                lines.append(row([
                    exercise.name,
                    record.metric.displayName,
                    number(record.value),
                    String(record.reps),
                    number(record.weight),
                    dateFormatter.string(from: record.date),
                ]))
            }
        }
        return lines.joined(separator: "\n")
    }
}
