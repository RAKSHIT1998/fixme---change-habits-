import Testing
import Foundation
import AVFoundation
@testable import FixMe

@MainActor
struct AlarmSoundAssetTests {

    /// If the Sounds folder ever stops being copied into the bundle, the alarm goes
    /// silent with no error anywhere — exactly the failure this app can least afford.
    @Test func alarmToneIsBundledAndUnderTheNotificationLimit() throws {
        let url = try #require(
            Bundle.main.url(forResource: "fixme_alarm", withExtension: "wav"),
            "fixme_alarm.wav is missing from the app bundle"
        )
        let player = try AVAudioPlayer(contentsOf: url)
        #expect(player.duration > 5)
        // iOS refuses to play a notification sound longer than 30 seconds.
        #expect(player.duration <= 30)
    }

    @Test func keepAliveTrackIsBundled() throws {
        let url = try #require(
            Bundle.main.url(forResource: "fixme_keepalive", withExtension: "wav"),
            "fixme_keepalive.wav is missing from the app bundle"
        )
        let player = try AVAudioPlayer(contentsOf: url)
        #expect(player.duration > 0)
    }

    @Test func schedulerPointsAtTheBundledTone() {
        #expect(AlarmScheduler.soundFileName == "fixme_alarm.wav")
        #expect(AlarmScheduler.followUpCount >= 1)
    }
}

@MainActor
struct AlarmFireDateTests {

    private func alarm(hour: Int, minute: Int, weekdays: [Int] = []) -> HabitAlarm {
        HabitAlarm(time: Date.fromComponents(hour: hour, minute: minute), weekdays: weekdays)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test func everydayAlarmLaterTodayFiresToday() throws {
        let now = date(2026, 9, 7, 6, 0)          // Monday 06:00
        let next = try #require(AlarmCoordinator.nextFireDate(for: alarm(hour: 7, minute: 30), from: now))

        let parts = Calendar.current.dateComponents([.day, .hour, .minute], from: next)
        #expect(parts.day == 7)
        #expect(parts.hour == 7)
        #expect(parts.minute == 30)
    }

    @Test func everydayAlarmAlreadyPassedRollsToTomorrow() throws {
        let now = date(2026, 9, 7, 9, 0)          // past the 07:30 alarm
        let next = try #require(AlarmCoordinator.nextFireDate(for: alarm(hour: 7, minute: 30), from: now))
        #expect(Calendar.current.dateComponents([.day], from: next).day == 8)
    }

    /// Weekday numbering is 1 = Sunday, and getting it wrong means alarms fire on the
    /// wrong days — the kind of bug that only shows up on a Monday morning.
    @Test func weekdayAlarmSkipsToTheNextSelectedDay() throws {
        // Saturday 2026-09-12, alarm set for Mondays only (weekday 2).
        let saturday = date(2026, 9, 12, 8, 0)
        let next = try #require(
            AlarmCoordinator.nextFireDate(for: alarm(hour: 7, minute: 0, weekdays: [2]), from: saturday)
        )
        #expect(Calendar.current.component(.weekday, from: next) == 2)
        #expect(Calendar.current.dateComponents([.day], from: next).day == 14)   // Monday
    }

    @Test func weekdayAlarmWithNoMatchingDayReturnsNil() {
        let weird = HabitAlarm(time: Date.fromComponents(hour: 7, minute: 0), weekdays: [99])
        #expect(AlarmCoordinator.nextFireDate(for: weird) == nil)
    }
}
