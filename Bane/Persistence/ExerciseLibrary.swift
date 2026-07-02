import Foundation
import SwiftData

/// The built-in starter catalog of exercises and the logic to seed it into the
/// SwiftData store on first launch.
///
/// Seeding is idempotent: it inserts the catalog only when the store contains
/// no built-in (`isCustom == false`) exercises, so it runs once on a fresh
/// install and is a cheap no-op on every launch thereafter. User-created
/// exercises (`isCustom == true`) are never touched.
enum ExerciseLibrary {
    /// A lightweight description of a built-in exercise. Kept separate from the
    /// `@Model` `Exercise` so the catalog is plain, allocation-free data until
    /// seeding actually materializes it.
    struct Seed {
        let name: String
        let category: ExerciseCategory
        let primaryMuscle: Muscle
        let equipment: Equipment
    }

    /// Inserts the built-in catalog if it has not been seeded yet.
    ///
    /// Safe to call on every launch — it queries for existing built-in
    /// exercises first and returns early when the library is already present.
    @MainActor
    static func seedIfNeeded(in context: ModelContext) {
        var descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isCustom == false }
        )
        descriptor.fetchLimit = 1

        let alreadySeeded = (try? context.fetchCount(descriptor)) ?? 0 > 0
        guard !alreadySeeded else { return }

        for seed in catalog {
            context.insert(
                Exercise(
                    name: seed.name,
                    category: seed.category,
                    primaryMuscle: seed.primaryMuscle,
                    equipment: seed.equipment,
                    isCustom: false
                )
            )
        }

        // Persist eagerly so the first browse of the library shows data even if
        // no other save has been triggered yet.
        try? context.save()
    }

    /// The starter catalog: ~75 common exercises spanning
    /// barbell / dumbbell / machine / cable / bodyweight / kettlebell work
    /// across every muscle group.
    static let catalog: [Seed] = [
        // MARK: Chest
        Seed(name: "Barbell Bench Press", category: .chest, primaryMuscle: .chest, equipment: .barbell),
        Seed(name: "Incline Barbell Bench Press", category: .chest, primaryMuscle: .chest, equipment: .barbell),
        Seed(name: "Dumbbell Bench Press", category: .chest, primaryMuscle: .chest, equipment: .dumbbell),
        Seed(name: "Incline Dumbbell Press", category: .chest, primaryMuscle: .chest, equipment: .dumbbell),
        Seed(name: "Dumbbell Fly", category: .chest, primaryMuscle: .chest, equipment: .dumbbell),
        Seed(name: "Cable Crossover", category: .chest, primaryMuscle: .chest, equipment: .cable),
        Seed(name: "Machine Chest Press", category: .chest, primaryMuscle: .chest, equipment: .machine),
        Seed(name: "Pec Deck", category: .chest, primaryMuscle: .chest, equipment: .machine),
        Seed(name: "Push-Up", category: .chest, primaryMuscle: .chest, equipment: .bodyweight),
        Seed(name: "Chest Dip", category: .chest, primaryMuscle: .chest, equipment: .bodyweight),

        // MARK: Back
        Seed(name: "Barbell Row", category: .back, primaryMuscle: .lats, equipment: .barbell),
        Seed(name: "Pendlay Row", category: .back, primaryMuscle: .upperBack, equipment: .barbell),
        Seed(name: "Bent-Over Dumbbell Row", category: .back, primaryMuscle: .lats, equipment: .dumbbell),
        Seed(name: "Single-Arm Dumbbell Row", category: .back, primaryMuscle: .lats, equipment: .dumbbell),
        Seed(name: "Pull-Up", category: .back, primaryMuscle: .lats, equipment: .bodyweight),
        Seed(name: "Chin-Up", category: .back, primaryMuscle: .lats, equipment: .bodyweight),
        Seed(name: "Lat Pulldown", category: .back, primaryMuscle: .lats, equipment: .cable),
        Seed(name: "Seated Cable Row", category: .back, primaryMuscle: .upperBack, equipment: .cable),
        Seed(name: "T-Bar Row", category: .back, primaryMuscle: .upperBack, equipment: .machine),
        Seed(name: "Machine Row", category: .back, primaryMuscle: .upperBack, equipment: .machine),
        Seed(name: "Face Pull", category: .back, primaryMuscle: .traps, equipment: .cable),
        Seed(name: "Back Extension", category: .back, primaryMuscle: .glutes, equipment: .bodyweight),

        // MARK: Legs
        Seed(name: "Back Squat", category: .legs, primaryMuscle: .quads, equipment: .barbell),
        Seed(name: "Front Squat", category: .legs, primaryMuscle: .quads, equipment: .barbell),
        Seed(name: "Conventional Deadlift", category: .legs, primaryMuscle: .hamstrings, equipment: .barbell),
        Seed(name: "Romanian Deadlift", category: .legs, primaryMuscle: .hamstrings, equipment: .barbell),
        Seed(name: "Leg Press", category: .legs, primaryMuscle: .quads, equipment: .machine),
        Seed(name: "Leg Extension", category: .legs, primaryMuscle: .quads, equipment: .machine),
        Seed(name: "Lying Leg Curl", category: .legs, primaryMuscle: .hamstrings, equipment: .machine),
        Seed(name: "Walking Lunge", category: .legs, primaryMuscle: .quads, equipment: .dumbbell),
        Seed(name: "Bulgarian Split Squat", category: .legs, primaryMuscle: .quads, equipment: .dumbbell),
        Seed(name: "Goblet Squat", category: .legs, primaryMuscle: .quads, equipment: .dumbbell),
        Seed(name: "Barbell Hip Thrust", category: .legs, primaryMuscle: .glutes, equipment: .barbell),
        Seed(name: "Standing Calf Raise", category: .legs, primaryMuscle: .calves, equipment: .machine),
        Seed(name: "Seated Calf Raise", category: .legs, primaryMuscle: .calves, equipment: .machine),
        Seed(name: "Bodyweight Squat", category: .legs, primaryMuscle: .quads, equipment: .bodyweight),

        // MARK: Shoulders
        Seed(name: "Overhead Press", category: .shoulders, primaryMuscle: .shoulders, equipment: .barbell),
        Seed(name: "Seated Dumbbell Shoulder Press", category: .shoulders, primaryMuscle: .shoulders, equipment: .dumbbell),
        Seed(name: "Arnold Press", category: .shoulders, primaryMuscle: .shoulders, equipment: .dumbbell),
        Seed(name: "Lateral Raise", category: .shoulders, primaryMuscle: .shoulders, equipment: .dumbbell),
        Seed(name: "Front Raise", category: .shoulders, primaryMuscle: .shoulders, equipment: .dumbbell),
        Seed(name: "Rear Delt Fly", category: .shoulders, primaryMuscle: .shoulders, equipment: .dumbbell),
        Seed(name: "Cable Lateral Raise", category: .shoulders, primaryMuscle: .shoulders, equipment: .cable),
        Seed(name: "Machine Shoulder Press", category: .shoulders, primaryMuscle: .shoulders, equipment: .machine),
        Seed(name: "Upright Row", category: .shoulders, primaryMuscle: .traps, equipment: .barbell),
        Seed(name: "Barbell Shrug", category: .shoulders, primaryMuscle: .traps, equipment: .barbell),
        Seed(name: "Dumbbell Shrug", category: .shoulders, primaryMuscle: .traps, equipment: .dumbbell),

        // MARK: Arms
        Seed(name: "Barbell Curl", category: .arms, primaryMuscle: .biceps, equipment: .barbell),
        Seed(name: "Dumbbell Curl", category: .arms, primaryMuscle: .biceps, equipment: .dumbbell),
        Seed(name: "Hammer Curl", category: .arms, primaryMuscle: .biceps, equipment: .dumbbell),
        Seed(name: "Preacher Curl", category: .arms, primaryMuscle: .biceps, equipment: .barbell),
        Seed(name: "Cable Curl", category: .arms, primaryMuscle: .biceps, equipment: .cable),
        Seed(name: "Concentration Curl", category: .arms, primaryMuscle: .biceps, equipment: .dumbbell),
        Seed(name: "Close-Grip Bench Press", category: .arms, primaryMuscle: .triceps, equipment: .barbell),
        Seed(name: "Triceps Pushdown", category: .arms, primaryMuscle: .triceps, equipment: .cable),
        Seed(name: "Overhead Triceps Extension", category: .arms, primaryMuscle: .triceps, equipment: .dumbbell),
        Seed(name: "Skull Crusher", category: .arms, primaryMuscle: .triceps, equipment: .barbell),
        Seed(name: "Triceps Dip", category: .arms, primaryMuscle: .triceps, equipment: .bodyweight),
        Seed(name: "Wrist Curl", category: .arms, primaryMuscle: .forearms, equipment: .dumbbell),

        // MARK: Core
        Seed(name: "Plank", category: .core, primaryMuscle: .abs, equipment: .bodyweight),
        Seed(name: "Crunch", category: .core, primaryMuscle: .abs, equipment: .bodyweight),
        Seed(name: "Hanging Leg Raise", category: .core, primaryMuscle: .abs, equipment: .bodyweight),
        Seed(name: "Cable Crunch", category: .core, primaryMuscle: .abs, equipment: .cable),
        Seed(name: "Russian Twist", category: .core, primaryMuscle: .obliques, equipment: .bodyweight),
        Seed(name: "Ab Wheel Rollout", category: .core, primaryMuscle: .abs, equipment: .bodyweight),
        Seed(name: "Sit-Up", category: .core, primaryMuscle: .abs, equipment: .bodyweight),

        // MARK: Cardio
        Seed(name: "Treadmill Run", category: .cardio, primaryMuscle: .fullBody, equipment: .machine),
        Seed(name: "Stationary Bike", category: .cardio, primaryMuscle: .quads, equipment: .machine),
        Seed(name: "Rowing Machine", category: .cardio, primaryMuscle: .fullBody, equipment: .machine),
        Seed(name: "Elliptical", category: .cardio, primaryMuscle: .fullBody, equipment: .machine),
        Seed(name: "Jump Rope", category: .cardio, primaryMuscle: .calves, equipment: .bodyweight),

        // MARK: Full Body
        Seed(name: "Kettlebell Swing", category: .fullBody, primaryMuscle: .glutes, equipment: .kettlebell),
        Seed(name: "Clean and Press", category: .fullBody, primaryMuscle: .shoulders, equipment: .barbell),
        Seed(name: "Thruster", category: .fullBody, primaryMuscle: .quads, equipment: .barbell),
        Seed(name: "Burpee", category: .fullBody, primaryMuscle: .fullBody, equipment: .bodyweight),
    ]
}
