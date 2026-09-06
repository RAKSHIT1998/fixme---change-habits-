import Foundation
import SwiftData

/// Aggregated summary for one calendar day of a journey — the daily score, journal, and photo.
@Model
final class DayProgress {
    var id: UUID
    var date: Date
    var dayNumber: Int
    var dailyScore: Int          // 0...100, app-generated motivational metric
    var journalEntry: String?
    var isDayComplete: Bool
    var journey: Journey?

    @Relationship(deleteRule: .cascade)
    var photo: DailyPhoto?

    init(
        id: UUID = UUID(),
        date: Date,
        dayNumber: Int,
        dailyScore: Int = 0,
        journalEntry: String? = nil,
        isDayComplete: Bool = false
    ) {
        self.id = id
        self.date = date
        self.dayNumber = dayNumber
        self.dailyScore = dailyScore
        self.journalEntry = journalEntry
        self.isDayComplete = isDayComplete
    }
}
