import Foundation
import UserNotifications

/// Reminders for an active challenge.
///
/// Two constraints shape all of this.
///
/// **iOS allows 64 pending local notifications per app.** Ninety days of reminders is far
/// past that, and the app also schedules alarms, so this keeps a rolling window of the
/// next few days and refreshes it whenever the app opens. A repeating trigger would fit in
/// one slot but can't say "Day 34 of 90" — and a countdown that doesn't count is worth
/// less than no countdown.
///
/// **Volume is a one-way door.** Someone who feels nagged turns notifications off
/// permanently, and a challenge whose reminders are muted is a challenge that fails. So
/// this replaces the generic daily nudges rather than stacking on top of them, staying
/// inside the same ceiling `SmartNotificationEngine` already respects, and the day's
/// warnings are cancelled the moment the day is actually done.
@MainActor
enum StakeNotifications {

    /// How many days ahead to schedule. Refreshed on every foreground, so this only has to
    /// cover someone who doesn't open the app for a while.
    static let windowDays = 5

    private static let prefix = "fixme.challenge."
    private static let lostID = prefix + "lost"

    private static func morningID(day: Int) -> String { "\(prefix)morning.\(day)" }
    private static func warningID(day: Int) -> String { "\(prefix)warning.\(day)" }

    /// Rebuilds the whole window from current state. Safe to call often — it clears its own
    /// notifications first, so it can't double-schedule.
    static func reschedule(
        challenge: StakeChallenge,
        habits: [Habit],
        calendar: Calendar = .current,
        now: Date = .now
    ) {
        clearAll()
        guard challenge.isActive else { return }

        let status = StakeRules.status(for: challenge, habits: habits, calendar: calendar, now: now)
        switch status {
        case .lost, .won:
            return
        case .safe, .atRisk:
            break
        }

        let today = StakeRules.dayNumber(for: challenge, on: now, calendar: calendar)
        let stake = challenge.formattedStake

        for offset in 0..<windowDays {
            let day = today + offset
            guard day <= challenge.lengthInDays,
                  let date = StakeRules.date(of: day, in: challenge, calendar: calendar)
            else { break }

            let isToday = offset == 0

            // Morning: name the day and what's riding on it. Skipped for today if the
            // morning has already passed — a "good morning" at 3pm reads like a bug.
            if let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date),
               morning > now {
                schedule(
                    id: morningID(day: day),
                    title: "Day \(day) of \(challenge.lengthInDays)",
                    body: morningBody(day: day, total: challenge.lengthInDays, stake: stake),
                    at: morning
                )
            }

            // Evening: the one that actually saves challenges. For today it's only worth
            // sending if something is still open.
            let openNow = isToday
                ? StakeRules.openHabitCount(habits: habits, on: date, calendar: calendar)
                : 1
            if openNow > 0,
               let warning = calendar.date(bySettingHour: 20, minute: 30, second: 0, of: date),
               warning > now {
                schedule(
                    id: warningID(day: day),
                    title: "⚠️ Day \(day) isn't done",
                    body: isToday
                        ? "\(openNow) habit\(openNow == 1 ? "" : "s") left. Miss today and the challenge — and \(stake) — is gone."
                        : "Finish today to keep the challenge alive. One miss ends it.",
                    at: warning
                )
            }
        }
    }

    /// Sent once, immediately, when a challenge is lost.
    ///
    /// Delivered rather than hidden: someone who staked money on this needs to find out
    /// from the app rather than discovering it days later. The copy states the fact and
    /// what happens next, and doesn't editorialise — there is nothing to gain from making
    /// someone feel worse about it.
    static func notifyLost(challenge: StakeChallenge, onDay day: Int) {
        clearAll()

        let content = UNMutableNotificationContent()
        content.title = "Day \(day) was missed"
        content.body = challenge.stakeHolder.isEmpty
            ? "The challenge is over. Your 90 days keep going — you can start a new challenge whenever you're ready."
            : "The challenge is over, and \(challenge.formattedStake) goes to \(challenge.stakeHolder). Your 90 days keep going."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: lostID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func clearAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Copy

    /// Escalates with what's actually at stake: early on the number is the motivator, and
    /// deep in it's the sunk effort, which by then is worth more than the money.
    static func morningBody(day: Int, total: Int, stake: String) -> String {
        let remaining = total - day
        switch day {
        case ..<7:
            return "\(stake) on the line. Every habit, today."
        case 7..<30:
            return "\(day) days kept, \(remaining) to go. One miss ends it."
        case 30..<75:
            return "\(day) days in. Losing now costs more than \(stake)."
        default:
            return remaining <= 1
                ? "Last day. Finish it."
                : "\(remaining) days left. Don't drop it here."
        }
    }

    private static func schedule(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
