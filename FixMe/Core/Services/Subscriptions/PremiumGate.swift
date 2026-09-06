import Foundation
import Observation

/// The free/premium boundary, in one place.
///
/// Packaging philosophy: the free tier has to be genuinely good or nobody sticks around
/// long enough to convert. So free keeps the whole core loop — habits, streaks, journey,
/// history, sharing — and premium sells *more of it* (unlimited habits, unlimited AI
/// verification, the good-looking templates, streak repair, insights).
@MainActor
@Observable
final class PremiumGate {
    nonisolated static let freeHabitLimit = 3
    nonisolated static let freeWeeklyAIVerifications = 3
    nonisolated static let freeMonthlyStreakFreezes = 1
    nonisolated static let premiumMonthlyStreakFreezes = 3

    /// Templates available without paying — enough to share proudly, not enough to stop wanting more.
    nonisolated static let freeShareTemplates: Set<ShareTemplate> = [.minimal, .dark, .light]

    private let subscriptions: SubscriptionService
    private let credit: ReferralCredit

    /// Mirrors `ReferralCredit`'s stored expiry so granting a week actually redraws the
    /// UI — the underlying value lives in UserDefaults, which Observation can't see.
    private(set) var referralPremiumUntil: Date?

    init(subscriptions: SubscriptionService, credit: ReferralCredit = ReferralCredit()) {
        self.subscriptions = subscriptions
        self.credit = credit
        self.referralPremiumUntil = credit.premiumUntil
    }

    /// A paid subscription, or an unexpired week earned by pairing with a friend.
    var isPremium: Bool { subscriptions.isSubscribed || hasReferralPremium }

    var hasReferralPremium: Bool {
        guard let referralPremiumUntil else { return false }
        return referralPremiumUntil > .now
    }

    /// True only when premium is *entirely* down to referral credit, which is what the
    /// subscription screen needs to know to avoid telling a paying subscriber their plan
    /// expires next Tuesday.
    var isOnReferralCreditOnly: Bool { hasReferralPremium && !subscriptions.isSubscribed }

    var referralDaysRemaining: Int { credit.daysRemaining() }
    var friendsCredited: Int { credit.friendsCredited }

    /// Called when a pairing completes. Returns whether a week was actually granted, so
    /// the UI can stay quiet for a friend who was already credited or a capped account.
    @discardableResult
    func grantReferralWeek(forPeerID peerID: String) -> Bool {
        let granted = credit.grant(forPeerID: peerID)
        if granted { referralPremiumUntil = credit.premiumUntil }
        return granted
    }

    func resetReferralCredit() {
        credit.reset()
        referralPremiumUntil = nil
    }

    // MARK: - Habits

    /// Quit habits are deliberately exempt from every limit below.
    ///
    /// Someone tracking days sober or smoke-free must never have that counter paused
    /// because they hit a billing threshold — it's the most health-critical thing in the
    /// app, and putting it behind a paywall would be indefensible regardless of what it
    /// did to conversion. Premium sells unlimited *build* habits instead.
    nonisolated static func countsTowardLimit(_ habit: Habit) -> Bool { !habit.isQuit }

    /// Splits a habit list into the ones the free tier keeps active and the ones it pauses.
    func partition(_ habits: [Habit]) -> (active: [Habit], paused: [Habit]) {
        guard !isPremium else { return (habits, []) }

        var active: [Habit] = []
        var paused: [Habit] = []
        var buildCount = 0

        for habit in habits {
            if !Self.countsTowardLimit(habit) {
                active.append(habit)
            } else if buildCount < Self.freeHabitLimit {
                active.append(habit)
                buildCount += 1
            } else {
                paused.append(habit)
            }
        }
        return (active, paused)
    }

    func canAddHabit(currentCount: Int) -> Bool {
        isPremium || currentCount < Self.freeHabitLimit
    }

    func canAddHabit(kind: HabitKind, existing: [Habit]) -> Bool {
        guard kind != .quit else { return true }
        return canAddHabit(currentCount: existing.filter(Self.countsTowardLimit).count)
    }

    func remainingFreeHabits(currentCount: Int) -> Int {
        max(Self.freeHabitLimit - currentCount, 0)
    }

    // MARK: - AI verification quota

    /// Verifications left this week. Premium returns `.max`.
    var remainingAIVerifications: Int {
        guard !isPremium else { return .max }
        return max(Self.freeWeeklyAIVerifications - AIVerificationQuota.usedThisWeek(), 0)
    }

    var canUseAIVerification: Bool { remainingAIVerifications > 0 }

    func recordAIVerificationUse() {
        guard !isPremium else { return }
        AIVerificationQuota.recordUse()
    }

    // MARK: - Templates

    func isTemplateUnlocked(_ template: ShareTemplate) -> Bool {
        isPremium || Self.freeShareTemplates.contains(template)
    }

    // MARK: - Streak freezes

    var monthlyStreakFreezeAllowance: Int {
        isPremium ? Self.premiumMonthlyStreakFreezes : Self.freeMonthlyStreakFreezes
    }

    var canRepairPastDay: Bool { isPremium }
}

/// Rolling 7-day counter for free-tier AI verifications, stored locally.
enum AIVerificationQuota {
    private static let key = "fixme.ai.verification.timestamps"

    static func usedThisWeek() -> Int {
        recentTimestamps().count
    }

    static func recordUse() {
        var stamps = recentTimestamps()
        stamps.append(.now)
        UserDefaults.standard.set(stamps.map(\.timeIntervalSince1970), forKey: key)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Timestamps within the last 7 days, pruning anything older on read.
    private static func recentTimestamps() -> [Date] {
        let raw = UserDefaults.standard.array(forKey: key) as? [TimeInterval] ?? []
        let cutoff = Date.now.addingTimeInterval(-7 * 24 * 60 * 60)
        return raw.map(Date.init(timeIntervalSince1970:)).filter { $0 > cutoff }
    }
}
