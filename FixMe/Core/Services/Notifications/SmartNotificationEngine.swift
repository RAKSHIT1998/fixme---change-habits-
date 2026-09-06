import Foundation
import UserNotifications

/// Behavioral re-engagement.
///
/// Notification volume is a one-way door: users who feel spammed disable notifications
/// permanently, and a habit app without notification permission has almost no way to
/// bring anyone back. So this engine is deliberately capped — at most a few scheduled
/// nudges a day, each tied to a real state in the user's journey rather than a marketing
/// calendar.
@MainActor
enum SmartNotificationEngine {

    /// Hard ceiling on scheduled local notifications per day.
    static let maxDailyNotifications = 3

    private enum ID {
        static let morning = "fixme.smart.morning"
        static let streakRisk = "fixme.smart.streakRisk"
        static let nightReview = "fixme.smart.nightReview"
        static let milestone = "fixme.smart.milestone"
    }

    static func scheduleBehavioralReminders(journey: Journey, notifications: NotificationManager) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            ID.morning, ID.streakRisk, ID.nightReview, ID.milestone,
        ])

        let dayNumber = journey.dayNumber()
        let streak = journey.habits.map { $0.currentStreak() }.max() ?? 0

        // 1. Morning: name the day, so opening the app has a purpose.
        schedule(
            id: ID.morning,
            title: "Day \(dayNumber) starts now",
            body: morningBody(streak: streak),
            hour: 7, minute: 0
        )

        // 2. Evening: the streak-protection nudge. Highest-intent message we send.
        if streak > 0 {
            schedule(
                id: ID.streakRisk,
                title: "🔥 \(streak) days on the line",
                body: "Anything still open today? Takes a minute to keep it alive.",
                hour: 19, minute: 30
            )
        }

        // 3. Night: close the loop, which is also what produces share cards.
        schedule(
            id: ID.nightReview,
            title: "Let's close the day",
            body: "Review Day \(dayNumber) and lock it in.",
            hour: 21, minute: 30
        )

        // 4. Milestone eve — anticipation beats congratulation for driving opens.
        if let next = Milestone.all.first(where: { $0.day == dayNumber + 1 }) {
            schedule(
                id: ID.milestone,
                title: "\(next.emoji) \(next.title) is tomorrow",
                body: "Day \(next.day). You're almost there.",
                hour: 20, minute: 0
            )
        }
    }

    /// One-off, sent the morning after a missed day. Framed as an invitation back,
    /// never as a scolding — guilt-based copy gets notifications turned off.
    static func scheduleComebackNudge(dayNumber: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Today still counts"
        content.body = "Yesterday didn't go as planned. Day \(dayNumber) is a clean slate."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "fixme.smart.comeback", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private static func morningBody(streak: Int) -> String {
        switch streak {
        case 0: return "Small win. Big change. Let's get one on the board."
        case 1...6: return "\(streak) days in. Keep it going."
        case 7...29: return "\(streak)-day streak. That's not luck anymore."
        default: return "\(streak) days. This is just who you are now."
        }
    }

    private static func schedule(id: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
