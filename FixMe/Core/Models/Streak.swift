import Foundation
import SwiftData

/// Overall journey-level streak bookkeeping (habit-specific streaks are computed from HabitCompletion).
@Model
final class Streak {
    var id: UUID
    var currentStreak: Int
    var bestStreak: Int
    var lastActiveDate: Date?
    var recoveryUsedDates: [Date]

    init(
        id: UUID = UUID(),
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        lastActiveDate: Date? = nil,
        recoveryUsedDates: [Date] = []
    ) {
        self.id = id
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.lastActiveDate = lastActiveDate
        self.recoveryUsedDates = recoveryUsedDates
    }
}
