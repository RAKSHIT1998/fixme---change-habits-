import Foundation
import SwiftData

/// Clean-time math for quit habits, kept out of the views so the "a relapse doesn't erase
/// your history" rule lives in exactly one place.
enum QuitProgressCalculator {

    // MARK: - Current run

    static func cleanTime(for habit: Habit, now: Date = .now) -> TimeInterval {
        guard let start = habit.quitStartDate else { return 0 }
        return max(now.timeIntervalSince(start), 0)
    }

    /// "12d 4h 33m" — the headline counter.
    static func formatted(_ interval: TimeInterval, includeSeconds: Bool = false) -> String {
        let total = Int(max(interval, 0))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60

        if days > 0 {
            return includeSeconds ? "\(days)d \(hours)h \(minutes)m \(seconds)s" : "\(days)d \(hours)h \(minutes)m"
        }
        if hours > 0 {
            return includeSeconds ? "\(hours)h \(minutes)m \(seconds)s" : "\(hours)h \(minutes)m"
        }
        return includeSeconds ? "\(minutes)m \(seconds)s" : "\(minutes)m"
    }

    // MARK: - History that survives a relapse

    /// Longest clean run ever, including the one currently running.
    static func longestRun(for habit: Habit, now: Date = .now) -> TimeInterval {
        let past = habit.relapses.map(\.runDuration).max() ?? 0
        return max(past, cleanTime(for: habit, now: now))
    }

    /// Every clean day the user has banked across all attempts — the number that makes a
    /// relapse survivable rather than a reason to quit quitting.
    static func totalCleanTime(for habit: Habit, now: Date = .now) -> TimeInterval {
        habit.relapses.reduce(0) { $0 + $1.runDuration } + cleanTime(for: habit, now: now)
    }

    static func attemptCount(for habit: Habit) -> Int {
        habit.relapses.count + 1
    }

    static func cravingsResisted(for habit: Habit) -> Int {
        habit.cravings.filter(\.didResist).count
    }

    // MARK: - Recovery timeline

    static func reachedMilestones(for habit: Habit, now: Date = .now) -> [RecoveryMilestone] {
        guard let program = habit.quitProgram else { return [] }
        let hours = cleanTime(for: habit, now: now) / 3_600
        return program.milestones.filter { $0.hours <= hours }
    }

    static func nextMilestone(for habit: Habit, now: Date = .now) -> RecoveryMilestone? {
        guard let program = habit.quitProgram else { return nil }
        let hours = cleanTime(for: habit, now: now) / 3_600
        return program.milestones.first { $0.hours > hours }
    }

    /// 0...1 progress from the previously reached milestone to the next one.
    static func progressToNextMilestone(for habit: Habit, now: Date = .now) -> Double {
        guard let next = nextMilestone(for: habit, now: now) else { return 1 }
        let hours = cleanTime(for: habit, now: now) / 3_600
        let previous = reachedMilestones(for: habit, now: now).last?.hours ?? 0
        let span = next.hours - previous
        guard span > 0 else { return 0 }
        return min(max((hours - previous) / span, 0), 1)
    }

    // MARK: - Mutations

    /// Records a relapse and starts a fresh run. Deliberately additive: nothing is deleted,
    /// so `totalCleanTime`, `longestRun` and `attemptCount` all keep their history.
    static func recordRelapse(
        for habit: Habit,
        trigger: String?,
        context: ModelContext,
        now: Date = .now
    ) {
        let event = RelapseEvent(
            date: now,
            runDuration: cleanTime(for: habit, now: now),
            trigger: trigger?.isEmpty == true ? nil : trigger
        )
        event.habit = habit
        habit.relapses.append(event)
        context.insert(event)

        habit.quitStartDate = now
        try? context.save()
    }

    static func recordCraving(
        for habit: Habit,
        intensity: Int,
        didResist: Bool,
        durationSeconds: Int,
        context: ModelContext
    ) {
        let event = CravingEvent(
            intensity: intensity,
            didResist: didResist,
            durationSeconds: durationSeconds
        )
        event.habit = habit
        habit.cravings.append(event)
        context.insert(event)
        try? context.save()
    }
}
