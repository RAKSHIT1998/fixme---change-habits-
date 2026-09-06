import Foundation
import SwiftData

@Model
final class NotificationPreference {
    var id: UUID
    var morningReminderEnabled: Bool
    var morningReminderTime: Date
    var middayCheckInEnabled: Bool
    var eveningCheckInEnabled: Bool
    var nightReviewEnabled: Bool
    var nightReviewTime: Date

    init(
        id: UUID = UUID(),
        morningReminderEnabled: Bool = true,
        morningReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 6, minute: 0)) ?? .now,
        middayCheckInEnabled: Bool = true,
        eveningCheckInEnabled: Bool = true,
        nightReviewEnabled: Bool = true,
        nightReviewTime: Date = Calendar.current.date(from: DateComponents(hour: 21, minute: 30)) ?? .now
    ) {
        self.id = id
        self.morningReminderEnabled = morningReminderEnabled
        self.morningReminderTime = morningReminderTime
        self.middayCheckInEnabled = middayCheckInEnabled
        self.eveningCheckInEnabled = eveningCheckInEnabled
        self.nightReviewEnabled = nightReviewEnabled
        self.nightReviewTime = nightReviewTime
    }
}
