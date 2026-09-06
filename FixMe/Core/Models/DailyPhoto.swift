import Foundation
import SwiftData

@Model
final class DailyPhoto {
    var id: UUID
    var fileName: String
    var category: String   // "morning", "workout", "food", "reading", "nature", "night"
    var capturedAt: Date

    init(id: UUID = UUID(), fileName: String, category: String = "morning", capturedAt: Date = .now) {
        self.id = id
        self.fileName = fileName
        self.category = category
        self.capturedAt = capturedAt
    }
}
