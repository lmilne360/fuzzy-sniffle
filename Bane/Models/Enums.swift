import Foundation

/// Broad grouping used to organize exercises in the library and pickers.
///
/// Stored directly on `Exercise` — SwiftData persists `RawRepresentable`
/// `Codable` enums natively (iOS 17+).
enum ExerciseCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case cardio
    case fullBody
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .legs: return "Legs"
        case .shoulders: return "Shoulders"
        case .arms: return "Arms"
        case .core: return "Core"
        case .cardio: return "Cardio"
        case .fullBody: return "Full Body"
        case .other: return "Other"
        }
    }
}

/// The primary muscle an exercise targets.
enum Muscle: String, Codable, CaseIterable, Identifiable, Sendable {
    case chest
    case upperBack
    case lats
    case traps
    case shoulders
    case biceps
    case triceps
    case forearms
    case quads
    case hamstrings
    case glutes
    case calves
    case abs
    case obliques
    case fullBody
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .upperBack: return "Upper Back"
        case .lats: return "Lats"
        case .traps: return "Traps"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .abs: return "Abs"
        case .obliques: return "Obliques"
        case .fullBody: return "Full Body"
        case .other: return "Other"
        }
    }
}

/// The equipment an exercise requires.
enum Equipment: String, Codable, CaseIterable, Identifiable, Sendable {
    case barbell
    case dumbbell
    case machine
    case cable
    case kettlebell
    case band
    case bodyweight
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .machine: return "Machine"
        case .cable: return "Cable"
        case .kettlebell: return "Kettlebell"
        case .band: return "Band"
        case .bodyweight: return "Bodyweight"
        case .other: return "Other"
        }
    }
}
