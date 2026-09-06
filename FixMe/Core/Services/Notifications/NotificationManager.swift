import Foundation
import UserNotifications

/// Wraps UNUserNotificationCenter with the app's specific reminder cadence.
/// All scheduling is local — no push infrastructure required.
struct NotificationManager {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Schedules the app's core daily reminder cadence based on user preferences.
    /// Existing reminders are replaced, never duplicated.
    func scheduleDailyReminders(preferences: NotificationPreference) {
        let ids = ["fixme.morning", "fixme.midday", "fixme.evening", "fixme.night"]
        center.removePendingNotificationRequests(withIdentifiers: ids)

        if preferences.morningReminderEnabled {
            schedule(
                id: "fixme.morning",
                title: "Rise and shine ☀️",
                body: "Today is waiting. Let's get moving.",
                time: preferences.morningReminderTime
            )
        }
        if preferences.middayCheckInEnabled {
            schedule(
                id: "fixme.midday",
                title: "Midday check-in",
                body: "How's the water mission going?",
                hour: 11, minute: 0
            )
        }
        if preferences.eveningCheckInEnabled {
            schedule(
                id: "fixme.evening",
                title: "Almost there",
                body: "A couple habits are still open today.",
                hour: 18, minute: 30
            )
        }
        if preferences.nightReviewEnabled {
            schedule(
                id: "fixme.night",
                title: "Let's close the day",
                body: "Review today and lock in your progress.",
                time: preferences.nightReviewTime
            )
        }
    }

    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }

    private func schedule(id: String, title: String, body: String, time: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        schedule(id: id, title: title, body: body, hour: comps.hour ?? 8, minute: comps.minute ?? 0)
    }

    private func schedule(id: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
