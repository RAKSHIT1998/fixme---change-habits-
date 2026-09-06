import Foundation
import SwiftData

/// A scheduled, repeating reminder that behaves as much like an alarm as iOS permits.
///
/// Important limitation, surfaced in the UI rather than hidden: a third-party app cannot
/// ring through Silent mode or a Focus without Apple's Critical Alerts entitlement, which
/// requires a special approval. These fire as Time Sensitive notifications, which do break
/// through most Focus modes and show on the lock screen with Done/Snooze actions.
@Model
final class HabitAlarm {
    var id: UUID
    var label: String
    /// Only hour and minute are meaningful; the date part is ignored.
    var time: Date
    /// Weekdays this fires on, using `Calendar` numbering (1 = Sunday … 7 = Saturday).
    /// Empty means every day.
    var weekdays: [Int]
    var isEnabled: Bool
    var snoozeMinutes: Int
    var soundFileName: String?
    var createdAt: Date
    var habit: Habit?

    init(
        id: UUID = UUID(),
        label: String = "Time to show up",
        time: Date = Date.fromComponents(hour: 7, minute: 0),
        weekdays: [Int] = [],
        isEnabled: Bool = true,
        snoozeMinutes: Int = 10,
        soundFileName: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.label = label
        self.time = time
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.snoozeMinutes = snoozeMinutes
        self.soundFileName = soundFileName
        self.createdAt = createdAt
    }

    var repeatsEveryDay: Bool { weekdays.isEmpty || weekdays.count == 7 }

    var repeatSummary: String {
        if repeatsEveryDay { return "Every day" }
        let symbols = Calendar.current.shortWeekdaySymbols
        let sorted = weekdays.sorted()
        if sorted == [2, 3, 4, 5, 6] { return "Weekdays" }
        if sorted == [1, 7] { return "Weekends" }
        return sorted.compactMap { index in
            let i = index - 1
            return i >= 0 && i < symbols.count ? symbols[i] : nil
        }.joined(separator: " ")
    }
}
