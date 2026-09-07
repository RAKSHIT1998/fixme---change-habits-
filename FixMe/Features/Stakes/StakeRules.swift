import Foundation

/// Where the challenge stands right now.
enum StakeStatus: Equatable {
    /// Running, and today is already fully done.
    case safe(day: Int, daysRemaining: Int)
    /// Running, but today still has habits open. The only state that can become `lost`.
    case atRisk(day: Int, daysRemaining: Int, openHabits: Int)
    /// A day ended with something unfinished. Terminal.
    case lost(onDay: Int)
    /// All days kept. Terminal.
    case won
}

/// Decides whether a challenge is still alive.
///
/// This is the one piece of the app that can take something away from someone, so it is
/// written to be read and argued with rather than trusted:
///
/// - **A day is kept only if every build habit due that day was completed.** Quit habits
///   count as kept unless a relapse was logged that day, matching how they work everywhere
///   else in the app.
/// - **Today is never judged.** A day can only fail once it is over, so the current day is
///   always `safe` or `atRisk`, never `lost`.
/// - **Habits added mid-challenge only count from the day they were created.** Otherwise
///   adding a habit on day 40 would retroactively fail days 1–39.
/// - **Streak freezes do not apply.** They exist to protect a streak from a bad day, which
///   is exactly the thing being staked here. A freeze that could save a challenge would
///   make the stake meaningless.
enum StakeRules {

    static func status(
        for challenge: StakeChallenge,
        habits: [Habit],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> StakeStatus {
        // A resolved challenge never re-evaluates: the outcome is a fact, not a view.
        switch challenge.outcome {
        case .lost: return .lost(onDay: challenge.failedOnDay ?? 0)
        case .won: return .won
        case .active: break
        }

        let today = dayNumber(for: challenge, on: now, calendar: calendar)

        // Every day that has already ended must have been kept.
        for day in 1..<max(today, 1) {
            guard let date = date(of: day, in: challenge, calendar: calendar) else { continue }
            if !dayWasKept(habits: habits, on: date, calendar: calendar) {
                return .lost(onDay: day)
            }
        }

        if today > challenge.lengthInDays {
            return .won
        }

        guard let todayDate = date(of: today, in: challenge, calendar: calendar) else {
            return .safe(day: today, daysRemaining: challenge.lengthInDays - today)
        }

        let open = openHabitCount(habits: habits, on: todayDate, calendar: calendar)
        let remaining = challenge.lengthInDays - today
        return open == 0
            ? .safe(day: today, daysRemaining: remaining)
            : .atRisk(day: today, daysRemaining: remaining, openHabits: open)
    }

    /// 1-indexed day of the challenge. Day 1 is the start date; can exceed `lengthInDays`
    /// once the final day is over, which is what signals a win.
    static func dayNumber(for challenge: StakeChallenge, on date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: challenge.startDate)
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        return max(days + 1, 1)
    }

    static func date(of day: Int, in challenge: StakeChallenge, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .day, value: day - 1, to: calendar.startOfDay(for: challenge.startDate))
    }

    /// Habits that were due on `date` and aren't done.
    static func openHabitCount(habits: [Habit], on date: Date, calendar: Calendar = .current) -> Int {
        due(habits, on: date, calendar: calendar).filter { !isKept($0, on: date, calendar: calendar) }.count
    }

    static func dayWasKept(habits: [Habit], on date: Date, calendar: Calendar = .current) -> Bool {
        let dueToday = due(habits, on: date, calendar: calendar)
        // A day with nothing to do can't be failed — that's the app's fault, not the user's.
        guard !dueToday.isEmpty else { return true }
        return dueToday.allSatisfy { isKept($0, on: date, calendar: calendar) }
    }

    /// Habits that existed on `date`. A habit created later can't retroactively fail a day.
    private static func due(_ habits: [Habit], on date: Date, calendar: Calendar) -> [Habit] {
        let day = calendar.startOfDay(for: date)
        return habits.filter { calendar.startOfDay(for: $0.createdAt) <= day }
    }

    private static func isKept(_ habit: Habit, on date: Date, calendar: Calendar) -> Bool {
        if habit.isQuit {
            // Clean unless the user logged a relapse — the same inversion used everywhere else.
            return !habit.relapsed(on: date, calendar: calendar)
        }
        return habit.completion(on: date, calendar: calendar)?.state.isDone == true
    }
}
