import Foundation
import SwiftData
import UserNotifications
import Observation

/// Bridges notification taps and actions back into the app.
///
/// Handles the two things an alarm must do beyond simply firing: let the user act on it
/// straight from the lock screen (Done / Snooze), and show a full-screen alarm when the
/// app is open or the notification is tapped.
@MainActor
@Observable
final class AlarmCoordinator: NSObject {

    /// Set when an alarm should be presented full-screen. The UI observes this.
    var ringingAlarmID: UUID?

    /// Owns the actual noise. A notification alone can't get past the ringer switch.
    let audio = AlarmAudioEngine()

    private var modelContainer: ModelContainer?

    func attach(container: ModelContainer) {
        self.modelContainer = container
        UNUserNotificationCenter.current().delegate = self
        AlarmScheduler.registerCategories()
    }

    /// Re-registers every enabled alarm. Pending notifications don't survive some system
    /// events, so this runs at launch rather than only when an alarm is edited.
    func refreshScheduledAlarms() async {
        guard let modelContainer else { return }
        let context = modelContainer.mainContext
        let alarms = (try? context.fetch(FetchDescriptor<HabitAlarm>())) ?? []
        let enabled = alarms.filter(\.isEnabled)
        await AlarmScheduler.rescheduleAll(enabled)

        // In loud mode the app stays alive, so it can fire real audio itself rather than
        // relying on a notification sound the ringer switch can mute.
        if audio.loudModeEnabled {
            audio.startKeepAlive()
            audio.armRingTimers(at: enabled.compactMap { Self.nextFireDate(for: $0) })
        } else {
            audio.cancelRingTimers()
        }
    }

    /// Next moment this alarm is due, honouring its repeat days.
    static func nextFireDate(for alarm: HabitAlarm, from now: Date = .now, calendar: Calendar = .current) -> Date? {
        let time = calendar.dateComponents([.hour, .minute], from: alarm.time)
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let candidate = calendar.date(
                    bySettingHour: time.hour ?? 7, minute: time.minute ?? 0, second: 0, of: day
                  ) else { continue }
            guard candidate > now else { continue }
            if alarm.repeatsEveryDay { return candidate }
            let weekday = calendar.component(.weekday, from: candidate)
            if alarm.weekdays.contains(weekday) { return candidate }
        }
        return nil
    }

    /// Called when the user deals with a ringing alarm.
    func dismissRinging(alarmID: UUID) async {
        audio.stop()
        ringingAlarmID = nil
        if let alarm = alarm(with: alarmID) {
            // Otherwise the +1/+2/+3 minute follow-ups still go off.
            await AlarmScheduler.silenceRemainingFollowUps(for: alarm)
        }
        await refreshScheduledAlarms()
    }

    // MARK: - Acting on an alarm

    private func alarm(with id: UUID) -> HabitAlarm? {
        guard let context = modelContainer?.mainContext else { return nil }
        let alarms = (try? context.fetch(FetchDescriptor<HabitAlarm>())) ?? []
        return alarms.first { $0.id == id }
    }

    /// Marks the alarm's habit complete for today, straight from the notification.
    func completeHabit(forAlarmID id: UUID) {
        guard let context = modelContainer?.mainContext,
              let habit = alarm(with: id)?.habit else { return }

        let existing = habit.completion(on: .now)
        let completion = existing ?? {
            let new = HabitCompletion(date: .now)
            new.habit = habit
            habit.completions.append(new)
            context.insert(new)
            return new
        }()

        guard !completion.state.isDone else { return }
        completion.state = .completed
        completion.completedAt = .now
        completion.progressValue = max(completion.progressValue, habit.goalTargetValue)
        completion.xpAwarded = XPService.awardForCompletion(verified: false)
        habit.journey?.owner?.totalXP += completion.xpAwarded
        try? context.save()
    }

    func snooze(alarmID id: UUID) async {
        guard let alarm = alarm(with: id) else { return }
        await AlarmScheduler.snooze(alarm)
    }
}

extension AlarmCoordinator: UNUserNotificationCenterDelegate {

    /// Alarms should be seen even with the app open — that's the whole point of an alarm.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let isAlarm = notification.request.content.categoryIdentifier == AlarmScheduler.categoryIdentifier
        let alarmID = (userInfo["alarmID"] as? String).flatMap(UUID.init(uuidString:))

        if isAlarm, let alarmID {
            Task { @MainActor in
                self.ringingAlarmID = alarmID
                // App is open at fire time — take over with real audio, which is far
                // louder than the notification sound and ignores the ringer switch.
                self.audio.ring()
            }
        }
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let alarmID = (userInfo["alarmID"] as? String).flatMap(UUID.init(uuidString:))
        let action = response.actionIdentifier

        Task { @MainActor in
            defer { completionHandler() }
            guard let alarmID else { return }

            switch action {
            case AlarmScheduler.doneActionIdentifier:
                self.completeHabit(forAlarmID: alarmID)
                await self.dismissRinging(alarmID: alarmID)
            case AlarmScheduler.snoozeActionIdentifier:
                await self.snooze(alarmID: alarmID)
                self.audio.stop()
            case UNNotificationDefaultActionIdentifier:
                // Tapped the notification — open the full-screen alarm and start ringing.
                self.ringingAlarmID = alarmID
                self.audio.ring()
            default:
                self.audio.stop()
            }
        }
    }
}
