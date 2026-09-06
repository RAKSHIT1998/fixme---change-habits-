import Foundation
import SwiftData

/// A habit the user has committed to for the duration of a journey.
@Model
final class Habit {
    var id: UUID
    var name: String
    var iconSystemName: String
    var category: HabitCategory
    var verificationType: VerificationType
    var goalDescription: String   // e.g. "10,000 steps", "20 pages", "3L"
    var goalTargetValue: Double   // numeric target, when applicable (steps, pages, ml, minutes)
    var goalUnit: String          // "steps", "pages", "ml", "min"
    var reminderTime: Date?
    var isReminderEnabled: Bool
    var createdAt: Date
    var sortOrder: Int
    var xpReward: Int
    var journey: Journey?

    // MARK: Quit-habit fields (unused when kind == .build)

    var kind: HabitKind = HabitKind.build
    /// Identifier into `QuitProgram.all` — drives the recovery timeline shown.
    var quitProgramID: String? = nil
    /// Start of the *current* clean run. Reset on relapse; history survives in `relapses`.
    var quitStartDate: Date? = nil
    /// Original start of the very first attempt, kept so total clean time can be reported.
    var quitFirstStartDate: Date? = nil
    var unitsPerDay: Double = 0
    var costPerUnit: Double = 0

    @Relationship(deleteRule: .cascade, inverse: \RelapseEvent.habit)
    var relapses: [RelapseEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \CravingEvent.habit)
    var cravings: [CravingEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \HabitAlarm.habit)
    var alarms: [HabitAlarm] = []

    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion] = []

    init(
        id: UUID = UUID(),
        name: String,
        iconSystemName: String,
        category: HabitCategory,
        verificationType: VerificationType,
        goalDescription: String,
        goalTargetValue: Double = 0,
        goalUnit: String = "",
        reminderTime: Date? = nil,
        isReminderEnabled: Bool = false,
        createdAt: Date = .now,
        sortOrder: Int = 0,
        xpReward: Int = 20,
        kind: HabitKind = .build,
        quitProgramID: String? = nil,
        quitStartDate: Date? = nil,
        unitsPerDay: Double = 0,
        costPerUnit: Double = 0
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.category = category
        self.verificationType = verificationType
        self.goalDescription = goalDescription
        self.goalTargetValue = goalTargetValue
        self.goalUnit = goalUnit
        self.reminderTime = reminderTime
        self.isReminderEnabled = isReminderEnabled
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.xpReward = xpReward
        self.kind = kind
        self.quitProgramID = quitProgramID
        self.quitStartDate = quitStartDate
        self.quitFirstStartDate = quitStartDate
        self.unitsPerDay = unitsPerDay
        self.costPerUnit = costPerUnit
    }

    var quitProgram: QuitProgram? { QuitProgram.program(id: quitProgramID) }

    var isQuit: Bool { kind == .quit }

    /// Money not spent during the current clean run.
    func moneySaved(now: Date = .now) -> Double {
        guard isQuit, let start = quitStartDate else { return 0 }
        let days = now.timeIntervalSince(start) / 86_400
        return max(days, 0) * unitsPerDay * costPerUnit
    }

    /// Units not consumed during the current clean run.
    func unitsAvoided(now: Date = .now) -> Int {
        guard isQuit, let start = quitStartDate else { return 0 }
        let days = now.timeIntervalSince(start) / 86_400
        return Int(max(days, 0) * unitsPerDay)
    }

    func relapsed(on date: Date, calendar: Calendar = .current) -> Bool {
        relapses.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func completion(on date: Date, calendar: Calendar = .current) -> HabitCompletion? {
        completions.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Current streak of consecutive completed days ending today (or yesterday if today is pending).
    func currentStreak(calendar: Calendar = .current, today: Date = .now) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: today)
        let doneDays = Set(completions.filter { $0.state.isDone }.map { calendar.startOfDay(for: $0.date) })

        if !doneDays.contains(cursor) {
            // Today not done yet — don't break the streak, just start counting from yesterday.
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while doneDays.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }
}
