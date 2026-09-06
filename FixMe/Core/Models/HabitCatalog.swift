import Foundation

/// Built-in library of suggested habits, keyed by category — powers onboarding's
/// "Pick your habits" screen and the smart-suggestion flow.
enum HabitCatalog {
    static let all: [HabitBlueprint] = [
        HabitBlueprint(name: "Wake up early", iconSystemName: "sunrise.fill", category: .energy, verificationType: .photoAI, goalDescription: "6:00 AM", goalTargetValue: 6, goalUnit: "hr"),
        HabitBlueprint(name: "10K Steps", iconSystemName: "figure.walk", category: .fitness, verificationType: .healthKit, goalDescription: "10,000 steps", goalTargetValue: 10000, goalUnit: "steps"),
        HabitBlueprint(name: "Drink Water", iconSystemName: "drop.fill", category: .health, verificationType: .manual, goalDescription: "3L", goalTargetValue: 3000, goalUnit: "ml"),
        HabitBlueprint(name: "Read", iconSystemName: "book.fill", category: .learning, verificationType: .manual, goalDescription: "20 pages", goalTargetValue: 20, goalUnit: "pages"),
        HabitBlueprint(name: "Workout", iconSystemName: "dumbbell.fill", category: .fitness, verificationType: .hybrid, goalDescription: "30 min", goalTargetValue: 30, goalUnit: "min"),
        HabitBlueprint(name: "Meditate", iconSystemName: "brain.head.profile", category: .calm, verificationType: .timer, goalDescription: "10 min", goalTargetValue: 10, goalUnit: "min"),
        HabitBlueprint(name: "Sleep on time", iconSystemName: "moon.stars.fill", category: .sleep, verificationType: .healthKit, goalDescription: "Before 11 PM", goalTargetValue: 23, goalUnit: "hr"),
        HabitBlueprint(name: "No phone (30 min)", iconSystemName: "iphone.slash", category: .digital, verificationType: .timer, goalDescription: "First 30 min awake", goalTargetValue: 30, goalUnit: "min"),
        HabitBlueprint(name: "Journal", iconSystemName: "pencil.and.outline", category: .mind, verificationType: .manual, goalDescription: "A few lines", goalTargetValue: 1, goalUnit: "entry"),
        HabitBlueprint(name: "Stretch", iconSystemName: "figure.flexibility", category: .fitness, verificationType: .timer, goalDescription: "10 min", goalTargetValue: 10, goalUnit: "min"),
        HabitBlueprint(name: "Eat vegetables", iconSystemName: "leaf.fill", category: .nutrition, verificationType: .manual, goalDescription: "2 servings", goalTargetValue: 2, goalUnit: "servings"),
        HabitBlueprint(name: "Go outside", iconSystemName: "sun.max.fill", category: .energy, verificationType: .manual, goalDescription: "15 min", goalTargetValue: 15, goalUnit: "min"),
        HabitBlueprint(name: "Run", iconSystemName: "figure.run", category: .fitness, verificationType: .healthKit, goalDescription: "3 km", goalTargetValue: 3, goalUnit: "km"),
        HabitBlueprint(name: "Study", iconSystemName: "graduationcap.fill", category: .learning, verificationType: .timer, goalDescription: "1 hour", goalTargetValue: 60, goalUnit: "min"),
        HabitBlueprint(name: "Take vitamins", iconSystemName: "pills.fill", category: .health, verificationType: .manual, goalDescription: "Daily dose", goalTargetValue: 1, goalUnit: "dose"),
    ]

    static func suggestions(for goal: String) -> [HabitBlueprint] {
        // Simple keyword-based mapping — a real system could use on-device ranking.
        let lower = goal.lowercased()
        if lower.contains("energy") {
            return filter(names: ["Wake up early", "10K Steps", "Drink Water", "Sleep on time", "Go outside", "Workout"])
        }
        if lower.contains("health") {
            return filter(names: ["10K Steps", "Drink Water", "Workout", "Sleep on time", "Eat vegetables", "Meditate"])
        }
        return all
    }

    private static func filter(names: [String]) -> [HabitBlueprint] {
        all.filter { names.contains($0.name) }
    }
}

/// Explore-tab built-in challenges.
enum ChallengeCatalog {
    static let all: [HabitTemplateSeed] = [
        HabitTemplateSeed(name: "5 AM Reset", description: "Own your mornings before the world wakes up.", duration: 30, difficulty: "Hard", category: .energy, habits: ["Wake up early", "Drink Water", "Go outside"]),
        HabitTemplateSeed(name: "30-Day Reading", description: "Build a real reading habit, one chapter at a time.", duration: 30, difficulty: "Easy", category: .learning, habits: ["Read", "Journal"]),
        HabitTemplateSeed(name: "10K Steps Challenge", description: "Move more, every single day.", duration: 30, difficulty: "Moderate", category: .fitness, habits: ["10K Steps"]),
        HabitTemplateSeed(name: "Better Sleep", description: "Consistent sleep, better everything.", duration: 21, difficulty: "Moderate", category: .sleep, habits: ["Sleep on time", "No phone (30 min)"]),
        HabitTemplateSeed(name: "Digital Detox", description: "Take back your attention.", duration: 14, difficulty: "Hard", category: .digital, habits: ["No phone (30 min)", "Journal"]),
        HabitTemplateSeed(name: "Strong Body", description: "A simple, repeatable training rhythm.", duration: 90, difficulty: "Hard", category: .fitness, habits: ["Workout", "Stretch", "10K Steps"]),
        HabitTemplateSeed(name: "Morning Person", description: "Become someone who wakes up with purpose.", duration: 21, difficulty: "Moderate", category: .energy, habits: ["Wake up early", "Drink Water", "Stretch"]),
        HabitTemplateSeed(name: "Deep Work", description: "Protect focus and get real work done.", duration: 30, difficulty: "Moderate", category: .learning, habits: ["Study", "No phone (30 min)"]),
        HabitTemplateSeed(name: "Mind Reset", description: "A calmer, steadier baseline.", duration: 30, difficulty: "Easy", category: .calm, habits: ["Meditate", "Journal"]),
    ]
}

struct HabitTemplateSeed: Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let duration: Int
    let difficulty: String
    let category: HabitCategory
    let habits: [String]

    var blueprints: [HabitBlueprint] {
        HabitCatalog.all.filter { habits.contains($0.name) }
    }
}
