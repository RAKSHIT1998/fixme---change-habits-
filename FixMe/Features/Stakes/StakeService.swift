import Foundation
import SwiftData

/// Evaluates a challenge and records the moment it ends.
///
/// Kept separate from `StakeRules` because the rules are a pure function of state and
/// this is the part with side effects: writing the outcome, telling the user, and standing
/// down the reminders. The rules can be reasoned about and tested without any of that.
@MainActor
struct StakeService {
    let modelContext: ModelContext

    func activeStake() -> StakeChallenge? {
        let descriptor = FetchDescriptor<StakeChallenge>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return (try? modelContext.fetch(descriptor))?.first { $0.isActive }
    }

    func allChallenges() -> [StakeChallenge] {
        let descriptor = FetchDescriptor<StakeChallenge>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @discardableResult
    func start(
        journey: Journey,
        stakeAmount: Double,
        stakeHolder: String,
        referee: Friend?,
        lengthInDays: Int? = nil,
        now: Date = .now
    ) -> StakeChallenge {
        let challenge = StakeChallenge(
            startDate: Calendar.current.startOfDay(for: now),
            lengthInDays: lengthInDays ?? journey.lengthInDays,
            stakeAmount: stakeAmount,
            stakeHolder: stakeHolder,
            refereePeerID: referee?.peerID,
            refereeName: referee?.displayName
        )
        challenge.journey = journey
        modelContext.insert(challenge)
        try? modelContext.save()
        return challenge
    }

    /// Re-evaluates and persists any transition to a terminal outcome. Returns the current
    /// status so callers can render from the same answer that was just recorded.
    @discardableResult
    func refresh(
        _ challenge: StakeChallenge,
        habits: [Habit],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> StakeStatus {
        let status = StakeRules.status(for: challenge, habits: habits, calendar: calendar, now: now)
        guard challenge.isActive else { return status }

        switch status {
        case let .lost(day):
            challenge.outcome = .lost
            challenge.failedOnDay = day
            challenge.resolvedAt = now
            try? modelContext.save()
            StakeNotifications.notifyLost(challenge: challenge, onDay: day)

        case .won:
            challenge.outcome = .won
            challenge.resolvedAt = now
            try? modelContext.save()
            StakeNotifications.clearAll()

        case .safe, .atRisk:
            StakeNotifications.reschedule(challenge: challenge, habits: habits, calendar: calendar, now: now)
        }
        return status
    }

    /// Ending it deliberately. Recorded as lost, because it is — the point of a stake is
    /// that walking away costs the same as failing.
    func giveUp(_ challenge: StakeChallenge, onDay day: Int, now: Date = .now) {
        challenge.outcome = .lost
        challenge.failedOnDay = day
        challenge.resolvedAt = now
        try? modelContext.save()
        StakeNotifications.clearAll()
    }
}
