import Foundation
import SwiftData

/// Evaluates badge-unlock criteria against a journey's habit history.
/// Deliberately simple/heuristic — good enough to feel earned without a scoring engine.
enum BadgeEvaluator {
    static func evaluate(journey: Journey, user: User, context: ModelContext) {
        var unlocked = Set(user.badges.map { $0.badgeIdentifier })

        func unlock(_ id: String) {
            guard !unlocked.contains(id) else { return }
            let badge = Badge(badgeIdentifier: id)
            badge.owner = user
            user.badges.append(badge)
            context.insert(badge)
            unlocked.insert(id)
        }

        let bestStreak = journey.habits.map { $0.currentStreak() }.max() ?? 0
        if bestStreak >= 14 { unlock("on_fire") }

        for habit in journey.habits {
            let doneCompletions = habit.completions.filter { $0.state.isDone }
            let lower = habit.name.lowercased()

            if lower.contains("wake"), doneCompletions.count >= 7 { unlock("early_bird") }
            if lower.contains("read") {
                let totalPages = doneCompletions.reduce(0) { $0 + $1.progressValue }
                if totalPages >= 100 { unlock("bookworm") }
            }
            if lower.contains("water"), doneCompletions.count >= 7 { unlock("hydrated") }
            if habit.goalUnit == "steps" {
                let totalSteps = doneCompletions.reduce(0) { $0 + $1.progressValue }
                if totalSteps >= 100_000 { unlock("walker") }
            }
            if lower.contains("meditat"), doneCompletions.count >= 10 { unlock("calm_mind") }
        }

        if journey.isComplete { unlock("ninety_days") }
    }
}
