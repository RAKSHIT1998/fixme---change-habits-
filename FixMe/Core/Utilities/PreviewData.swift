import Foundation
import SwiftData

/// Realistic, populated demo data — used by SwiftUI previews and available as a "demo mode"
/// so the app never looks empty during development. Not used in production launches.
enum PreviewData {
    @MainActor
    static let container: ModelContainer = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext

        let user = User(name: "Alex", totalXP: 860)
        user.settings = UserSettings(healthKitAuthorized: true, notificationsAuthorized: true)
        context.insert(user)

        let journey = Journey(
            startDate: Calendar.current.date(byAdding: .day, value: -16, to: .now.startOfDay) ?? .now,
            commitmentLevel: .committed
        )
        journey.owner = user
        context.insert(journey)

        let blueprints: [HabitBlueprint] = [
            HabitCatalog.all[0], // Wake up early
            HabitCatalog.all[1], // 10K steps
            HabitCatalog.all[2], // Drink water
            HabitCatalog.all[3], // Read
            HabitCatalog.all[4], // Workout
        ]

        for (index, bp) in blueprints.enumerated() {
            let habit = bp.makeHabit(sortOrder: index)
            habit.journey = journey
            context.insert(habit)

            // Backfill 16 days of mostly-completed history for a realistic streak.
            for dayOffset in stride(from: -16, through: -1, by: 1) {
                let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: .now.startOfDay) ?? .now
                let completion = HabitCompletion(date: date)
                completion.habit = habit
                let missed = dayOffset == -5 // one realistic miss
                completion.state = missed ? .missed : .completed
                completion.progressValue = missed ? 0 : habit.goalTargetValue
                completion.xpAwarded = missed ? 0 : 20
                habit.completions.append(completion)
                context.insert(completion)
            }

            // Today's partial progress, varied per habit.
            let today = HabitCompletion(date: .now)
            today.habit = habit
            switch index {
            case 0: today.state = .verified; today.progressValue = habit.goalTargetValue
            case 1: today.state = .inProgress; today.progressValue = 7482
            case 2: today.state = .inProgress; today.progressValue = 2100
            case 3: today.state = .inProgress; today.progressValue = 12
            default: today.state = .notStarted
            }
            habit.completions.append(today)
            context.insert(today)
        }

        try? context.save()
        return container
    }()
}
