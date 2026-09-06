import Foundation
import SwiftData

/// Streak protection.
///
/// The streak is the retention mechanic, which makes losing one the moment users churn.
/// So the app is deliberately generous about saving it: everyone gets a free freeze each
/// month, and a missed day is framed as recoverable rather than fatal. Premium sells
/// *more* protection, never the only protection — gating recovery entirely is how a habit
/// app earns refunds and one-star reviews.
@MainActor
enum StreakFreezeService {

    /// Whether the user still has a habit open today with limited time left. Drives the
    /// "don't break your streak" nudge, which is the single highest-intent moment we have.
    static func isStreakAtRisk(habits: [Habit], now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard !habits.isEmpty else { return false }
        let hour = calendar.component(.hour, from: now)
        guard hour >= 17 else { return false }
        let anyOpen = habits.contains { !( $0.completion(on: now)?.state.isDone ?? false ) }
        let hasStreak = habits.contains { $0.currentStreak(today: now) > 0 }
        return anyOpen && hasStreak
    }

    /// Yesterday had habits but none were completed — the comeback moment.
    static func missedYesterday(habits: [Habit], now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard !habits.isEmpty,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return false }
        let anyDone = habits.contains { $0.completion(on: yesterday)?.state.isDone ?? false }
        return !anyDone
    }

    /// The streak that's on the line right now — what the user stands to lose today.
    static func streakAtStake(habits: [Habit], now: Date = .now) -> Int {
        habits.map { $0.currentStreak(today: now) }.max() ?? 0
    }

    /// The streak that *was* running up to the day before yesterday — i.e. what a freeze
    /// would restore. Once a day is missed, `currentStreak` is already 0, so this is the
    /// number the recovery UI has to show; using `streakAtStake` there would render the
    /// freeze offer permanently invisible.
    static func recoverableStreak(habits: [Habit], now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: now) else { return 0 }
        return habits.map { $0.currentStreak(today: dayBeforeYesterday) }.max() ?? 0
    }

    // MARK: - Freezes

    static func remainingFreezes(for user: User, gate: PremiumGate, now: Date = .now) -> Int {
        resetIfNewMonth(user: user, now: now)
        return max(gate.monthlyStreakFreezeAllowance - user.streakFreezesUsedThisMonth, 0)
    }

    /// Consumes a freeze and marks yesterday's habits as protected, so the streak survives.
    @discardableResult
    static func applyFreeze(
        user: User,
        habits: [Habit],
        gate: PremiumGate,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard remainingFreezes(for: user, gate: gate, now: now) > 0,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return false }

        for habit in habits {
            let completion = habit.completion(on: yesterday) ?? {
                let new = HabitCompletion(date: yesterday)
                new.habit = habit
                habit.completions.append(new)
                context.insert(new)
                return new
            }()
            // A frozen day counts as kept, but earns no XP — protection, not a shortcut.
            completion.state = .completed
            completion.xpAwarded = 0
        }

        user.streakFreezesUsedThisMonth += 1
        try? context.save()
        Haptics.notify(.success)
        return true
    }

    private static func resetIfNewMonth(user: User, now: Date, calendar: Calendar = .current) {
        let currentMonth = calendar.dateInterval(of: .month, for: now)?.start
        guard let currentMonth else { return }
        if user.lastFreezeResetMonth != currentMonth {
            user.lastFreezeResetMonth = currentMonth
            user.streakFreezesUsedThisMonth = 0
        }
    }
}
