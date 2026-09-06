import Foundation
import SwiftData

/// A reusable bundle of habits — either a built-in Explore challenge or a user-created template.
@Model
final class HabitTemplate {
    var id: UUID
    var name: String
    var templateDescription: String
    var durationDays: Int
    var difficulty: String   // "Easy", "Moderate", "Hard"
    var category: HabitCategory
    var isUserCreated: Bool
    var isPublished: Bool
    var habitBlueprints: [HabitBlueprint]

    init(
        id: UUID = UUID(),
        name: String,
        templateDescription: String,
        durationDays: Int = 90,
        difficulty: String = "Moderate",
        category: HabitCategory = .custom,
        isUserCreated: Bool = false,
        isPublished: Bool = false,
        habitBlueprints: [HabitBlueprint] = []
    ) {
        self.id = id
        self.name = name
        self.templateDescription = templateDescription
        self.durationDays = durationDays
        self.difficulty = difficulty
        self.category = category
        self.isUserCreated = isUserCreated
        self.isPublished = isPublished
        self.habitBlueprints = habitBlueprints
    }
}

/// Lightweight, Codable description of a habit — used inside templates before a Habit is materialized.
struct HabitBlueprint: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var iconSystemName: String
    var category: HabitCategory
    var verificationType: VerificationType
    var goalDescription: String
    var goalTargetValue: Double = 0
    var goalUnit: String = ""

    func makeHabit(sortOrder: Int = 0) -> Habit {
        Habit(
            name: name,
            iconSystemName: iconSystemName,
            category: category,
            verificationType: verificationType,
            goalDescription: goalDescription,
            goalTargetValue: goalTargetValue,
            goalUnit: goalUnit,
            sortOrder: sortOrder
        )
    }
}
