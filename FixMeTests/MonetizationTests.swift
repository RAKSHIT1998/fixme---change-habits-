import Testing
import Foundation
@testable import FixMe

/// The free/premium boundary decides revenue, so it gets tested directly rather than
/// only being exercised through the UI.
@MainActor
struct PremiumGateTests {

    /// A gate wired to a subscription service with no products loaded — i.e. a real free user.
    private func freeGate() -> PremiumGate {
        PremiumGate(subscriptions: SubscriptionService())
    }

    @Test func freeUsersCanAddUpToTheLimitAndNoFurther() {
        let gate = freeGate()
        #expect(gate.canAddHabit(currentCount: 0))
        #expect(gate.canAddHabit(currentCount: PremiumGate.freeHabitLimit - 1))
        #expect(!gate.canAddHabit(currentCount: PremiumGate.freeHabitLimit))
        #expect(!gate.canAddHabit(currentCount: PremiumGate.freeHabitLimit + 5))
    }

    @Test func remainingFreeHabitsNeverGoesNegative() {
        let gate = freeGate()
        #expect(gate.remainingFreeHabits(currentCount: PremiumGate.freeHabitLimit + 3) == 0)
        #expect(gate.remainingFreeHabits(currentCount: 1) == PremiumGate.freeHabitLimit - 1)
    }

    @Test func starterTemplatesAreFreeAndPremiumOnesAreNot() {
        let gate = freeGate()
        #expect(gate.isTemplateUnlocked(.minimal))
        #expect(gate.isTemplateUnlocked(.dark))
        #expect(!gate.isTemplateUnlocked(.ninetyDay))
        #expect(!gate.isTemplateUnlocked(.motivational))
    }

    @Test func freeTierStillGetsAStreakFreezeEveryMonth() {
        // Recovery is never entirely paywalled — a habit app that lets a lapse become
        // permanent loses the user, paying or not.
        #expect(freeGate().monthlyStreakFreezeAllowance >= 1)
        #expect(PremiumGate.premiumMonthlyStreakFreezes > PremiumGate.freeMonthlyStreakFreezes)
    }
}

@MainActor
struct AIVerificationQuotaTests {

    @Test func quotaCountsUsesAndThenBlocks() {
        AIVerificationQuota.reset()
        defer { AIVerificationQuota.reset() }

        let gate = PremiumGate(subscriptions: SubscriptionService())
        #expect(gate.canUseAIVerification)
        #expect(gate.remainingAIVerifications == PremiumGate.freeWeeklyAIVerifications)

        for _ in 0..<PremiumGate.freeWeeklyAIVerifications {
            gate.recordAIVerificationUse()
        }

        #expect(gate.remainingAIVerifications == 0)
        #expect(!gate.canUseAIVerification)
    }

    @Test func usesOlderThanAWeekFallOutOfTheWindow() {
        AIVerificationQuota.reset()
        defer { AIVerificationQuota.reset() }

        // Two uses from 8 days ago should not count against this week.
        let stale = Date.now.addingTimeInterval(-8 * 24 * 60 * 60).timeIntervalSince1970
        UserDefaults.standard.set([stale, stale], forKey: "fixme.ai.verification.timestamps")

        #expect(AIVerificationQuota.usedThisWeek() == 0)
    }
}

@MainActor
struct StreakProtectionTests {

    private func makeHabit(completedOffsets: [Int]) -> Habit {
        let habit = HabitCatalog.all[3].makeHabit()
        for offset in completedOffsets {
            let date = Calendar.current.date(byAdding: .day, value: offset, to: .now.startOfDay)!
            let completion = HabitCompletion(date: date, state: .completed)
            completion.habit = habit
            habit.completions.append(completion)
        }
        return habit
    }

    @Test func missedYesterdayDetectsAGapInTheHistory() {
        let missed = makeHabit(completedOffsets: [-3, -2])       // nothing yesterday
        let kept = makeHabit(completedOffsets: [-2, -1])         // yesterday done

        #expect(StreakFreezeService.missedYesterday(habits: [missed]))
        #expect(!StreakFreezeService.missedYesterday(habits: [kept]))
    }

    @Test func noHabitsMeansNothingIsAtRisk() {
        // Guards against nagging a user who has nothing set up yet.
        #expect(!StreakFreezeService.missedYesterday(habits: []))
        #expect(!StreakFreezeService.isStreakAtRisk(habits: []))
    }

    @Test func streakIsNotConsideredAtRiskEarlyInTheDay() {
        let habit = makeHabit(completedOffsets: [-2, -1])
        let morning = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
        #expect(!StreakFreezeService.isStreakAtRisk(habits: [habit], now: morning))
    }

    @Test func streakAtStakeReportsTheLongestRunningStreak() {
        let short = makeHabit(completedOffsets: [-1])
        let long = makeHabit(completedOffsets: [-3, -2, -1])
        #expect(StreakFreezeService.streakAtStake(habits: [short, long]) == 3)
    }
}

@MainActor
struct StreakRecoveryTests {

    private func makeHabit(completedOffsets: [Int]) -> Habit {
        let habit = HabitCatalog.all[3].makeHabit()
        for offset in completedOffsets {
            let date = Calendar.current.date(byAdding: .day, value: offset, to: .now.startOfDay)!
            let completion = HabitCompletion(date: date, state: .completed)
            completion.habit = habit
            habit.completions.append(completion)
        }
        return habit
    }

    /// Regression: the freeze offer is keyed off the *recoverable* streak. Keying it off
    /// the current streak made the button unreachable, because missing a day zeroes that
    /// out before the recovery UI ever renders.
    @Test func recoverableStreakSurvivesTheMissedDay() {
        // Four solid days, then yesterday missed.
        let habit = makeHabit(completedOffsets: [-5, -4, -3, -2])

        #expect(StreakFreezeService.missedYesterday(habits: [habit]))
        #expect(StreakFreezeService.streakAtStake(habits: [habit]) == 0)
        #expect(StreakFreezeService.recoverableStreak(habits: [habit]) == 4)
    }

    @Test func nothingToRecoverWhenThereWasNoStreak() {
        let habit = makeHabit(completedOffsets: [])
        #expect(StreakFreezeService.recoverableStreak(habits: [habit]) == 0)
    }
}
