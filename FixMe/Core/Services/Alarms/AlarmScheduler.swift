import Foundation
import UserNotifications

/// Schedules alarm-style reminders.
///
/// What iOS actually allows a third-party app to do: repeating local notifications with
/// `.timeSensitive` interruption level (which breaks through most Focus modes), a lock
/// screen presentation, and Done/Snooze actions. What it does *not* allow without Apple's
/// Critical Alerts entitlement — a separate application and approval — is ringing through
/// Silent mode or a Do Not Disturb the user has explicitly set. `AlarmLimitationNotice`
/// puts that in front of the user instead of letting them discover it at 6am.
@MainActor
enum AlarmScheduler {

    nonisolated static let categoryIdentifier = "FIXME_ALARM"
    /// Bundled 29s tone — the ceiling for a notification sound is 30 seconds.
    nonisolated static let soundFileName = "fixme_alarm.wav"
    /// Extra notifications after the first, one per minute, so a single missed chime
    /// isn't the end of it.
    nonisolated static let followUpCount = 3
    nonisolated static let doneActionIdentifier = "FIXME_ALARM_DONE"
    nonisolated static let snoozeActionIdentifier = "FIXME_ALARM_SNOOZE"

    /// Registers the Done/Snooze buttons that appear on the notification. Must run before
    /// any alarm is delivered, so it's called at launch.
    static func registerCategories() {
        let done = UNNotificationAction(
            identifier: doneActionIdentifier,
            title: "Mark done",
            options: [.authenticationRequired]
        )
        let snooze = UNNotificationAction(
            identifier: snoozeActionIdentifier,
            title: "Snooze",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [done, snooze],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Scheduling

    static func reschedule(_ alarm: HabitAlarm) async {
        cancel(alarm)
        guard alarm.isEnabled else { return }

        let comps = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
        let hour = comps.hour ?? 7
        let minute = comps.minute ?? 0

        // An empty weekday set means "every day", which is one repeating trigger.
        // Otherwise iOS needs one repeating trigger per weekday.
        let days: [Int?] = alarm.repeatsEveryDay ? [nil] : alarm.weekdays.sorted().map { $0 }

        for day in days {
            for offset in 0...Self.followUpCount {
                // Roll the minute forward so follow-ups land at +1, +2, +3 minutes,
                // carrying into the next hour correctly.
                let total = hour * 60 + minute + offset
                var dateComponents = DateComponents()
                dateComponents.hour = (total / 60) % 24
                dateComponents.minute = total % 60
                if let day { dateComponents.weekday = day }

                let content = makeContent(for: alarm)
                if offset > 0 {
                    content.title = "Still going — \(alarm.label)"
                }
                let request = UNNotificationRequest(
                    identifier: identifier(for: alarm, weekday: day, offset: offset),
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                )
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    static func cancel(_ alarm: HabitAlarm) {
        var ids: [String] = []
        for offset in 0...followUpCount {
            ids.append(identifier(for: alarm, weekday: nil, offset: offset))
            ids.append(contentsOf: (1...7).map { identifier(for: alarm, weekday: $0, offset: offset) })
        }
        ids.append(snoozeIdentifier(for: alarm))
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Stops the remaining follow-ups for an alarm that's already been dealt with, then
    /// re-arms it so tomorrow still fires. Without this, dismissing at 6:00 still leaves
    /// three more notifications queued for 6:01, 6:02 and 6:03.
    static func silenceRemainingFollowUps(for alarm: HabitAlarm) async {
        cancel(alarm)
        await reschedule(alarm)
    }

    static func rescheduleAll(_ alarms: [HabitAlarm]) async {
        for alarm in alarms {
            await reschedule(alarm)
        }
    }

    /// Fires a one-off notification `snoozeMinutes` from now.
    static func snooze(_ alarm: HabitAlarm) async {
        let content = makeContent(for: alarm)
        content.title = "Snoozed — \(alarm.label)"
        let request = UNNotificationRequest(
            identifier: snoozeIdentifier(for: alarm),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(max(alarm.snoozeMinutes, 1) * 60),
                repeats: false
            )
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Content

    private static func makeContent(for alarm: HabitAlarm) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.label
        content.body = alarm.habit.map { "\($0.name) — \($0.goalDescription)" } ?? "Time to show up."
        // The bundled tone is far more cutting than the default chime. It still respects
        // the ringer switch — only in-app playback can get past that.
        content.sound = UNNotificationSound(
            named: UNNotificationSoundName(alarm.soundFileName ?? Self.soundFileName)
        )
        content.categoryIdentifier = categoryIdentifier
        // Time Sensitive is the strongest level available without the Critical Alerts
        // entitlement; it breaks through most Focus modes but respects the ringer switch.
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "alarmID": alarm.id.uuidString,
            "habitID": alarm.habit?.id.uuidString ?? "",
        ]
        return content
    }

    private static func identifier(for alarm: HabitAlarm, weekday: Int?, offset: Int = 0) -> String {
        let base = weekday.map { "fixme.alarm.\(alarm.id.uuidString).\($0)" }
            ?? "fixme.alarm.\(alarm.id.uuidString)"
        return offset == 0 ? base : "\(base).f\(offset)"
    }

    private static func snoozeIdentifier(for alarm: HabitAlarm) -> String {
        "fixme.alarm.snooze.\(alarm.id.uuidString)"
    }
}
