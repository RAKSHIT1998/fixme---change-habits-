import Foundation
import SwiftData

/// Records a single day's attempt/result for one habit.
@Model
final class HabitCompletion {
    var id: UUID
    var date: Date
    var state: HabitDayState
    var progressValue: Double   // current progress toward habit.goalTargetValue
    var completedAt: Date?
    var xpAwarded: Int
    var habit: Habit?

    @Relationship(deleteRule: .cascade)
    var verification: VerificationResult?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        state: HabitDayState = .notStarted,
        progressValue: Double = 0,
        completedAt: Date? = nil,
        xpAwarded: Int = 0
    ) {
        self.id = id
        self.date = date
        self.state = state
        self.progressValue = progressValue
        self.completedAt = completedAt
        self.xpAwarded = xpAwarded
    }
}
