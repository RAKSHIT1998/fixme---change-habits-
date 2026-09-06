import Foundation
import SwiftData

/// A single 90-day transformation journey.
@Model
final class Journey {
    var id: UUID
    var title: String
    var startDate: Date
    var lengthInDays: Int
    var commitmentLevel: CommitmentLevel
    var isActive: Bool
    var completedAt: Date?
    var owner: User?

    @Relationship(deleteRule: .cascade, inverse: \Habit.journey)
    var habits: [Habit] = []

    @Relationship(deleteRule: .cascade, inverse: \DayProgress.journey)
    var dayProgresses: [DayProgress] = []

    init(
        id: UUID = UUID(),
        title: String = "My 90 Days",
        startDate: Date = Calendar.current.startOfDay(for: .now),
        lengthInDays: Int = 90,
        commitmentLevel: CommitmentLevel = .committed,
        isActive: Bool = true,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.lengthInDays = lengthInDays
        self.commitmentLevel = commitmentLevel
        self.isActive = isActive
        self.completedAt = completedAt
    }

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: lengthInDays - 1, to: startDate) ?? startDate
    }

    /// 1-indexed day number for `date`. Clamped to [1, lengthInDays].
    func dayNumber(for date: Date = .now, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        return min(max(days + 1, 1), lengthInDays)
    }

    var daysRemaining: Int { max(lengthInDays - dayNumber(), 0) }

    var isComplete: Bool { completedAt != nil || dayNumber() >= lengthInDays && Calendar.current.startOfDay(for: .now) > Calendar.current.startOfDay(for: endDate) }
}
