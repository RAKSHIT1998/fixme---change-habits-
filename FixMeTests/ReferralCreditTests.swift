import Testing
import Foundation
import SwiftData
import CryptoKit
@testable import FixMe

/// This grants real paid features with no server to verify anything, so the limits that
/// stop it becoming unlimited free premium are the part worth pinning down.
struct ReferralCreditTests {

    /// Each test gets its own defaults suite — these run in parallel, and sharing
    /// `.standard` would make them flake against each other.
    private func freshCredit() -> ReferralCredit {
        let suite = "fixme.tests.\(UUID().uuidString)"
        return ReferralCredit(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func pairingGrantsAWeek() {
        let credit = freshCredit()
        #expect(credit.isActive() == false)

        #expect(credit.grant(forPeerID: "sam") == true)
        #expect(credit.isActive())
        #expect(credit.daysRemaining() == ReferralCredit.daysPerFriend)
        #expect(credit.friendsCredited == 1)
    }

    /// Unpair, re-pair, earn another week — the obvious way to farm this, and the one
    /// thing a device with no server can actually prevent.
    @Test func theSameFriendOnlyEverCountsOnce() {
        let credit = freshCredit()
        #expect(credit.grant(forPeerID: "sam") == true)
        #expect(credit.grant(forPeerID: "sam") == false)
        #expect(credit.friendsCredited == 1)
        #expect(credit.daysRemaining() == 7)
    }

    /// A second friend during an active week should extend it, not restart it — otherwise
    /// pairing with two people on the same day silently costs you a week.
    @Test func weeksStackRatherThanOverwrite() {
        let credit = freshCredit()
        credit.grant(forPeerID: "sam")
        credit.grant(forPeerID: "alex")
        #expect(credit.daysRemaining() == 14)
        #expect(credit.friendsCredited == 2)
    }

    @Test func stopsAtTheLifetimeCap() {
        let credit = freshCredit()
        let allowed = ReferralCredit.maxEarnedDays / ReferralCredit.daysPerFriend

        for index in 0..<allowed {
            #expect(credit.grant(forPeerID: "friend\(index)") == true)
        }
        #expect(credit.hasReachedCap)
        #expect(credit.grant(forPeerID: "one-too-many") == false)
        #expect(credit.earnedDays == ReferralCredit.maxEarnedDays)
    }

    @Test func creditExpires() {
        let credit = freshCredit()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        credit.grant(forPeerID: "sam", now: start)

        #expect(credit.isActive(now: start.addingTimeInterval(6 * 86_400)))
        #expect(credit.isActive(now: start.addingTimeInterval(8 * 86_400)) == false)
        #expect(credit.daysRemaining(now: start.addingTimeInterval(8 * 86_400)) == 0)
    }

    /// Hours left is still a day left. Rounding down would tell someone their premium is
    /// already gone while they're still using it.
    @Test func partialDaysRoundUp() {
        let credit = freshCredit()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        credit.grant(forPeerID: "sam", now: start)
        #expect(credit.daysRemaining(now: start.addingTimeInterval(6.5 * 86_400)) == 1)
    }

    /// "Delete my data" has to reach this too — it lives outside SwiftData.
    @Test func resetClearsEverything() {
        let credit = freshCredit()
        credit.grant(forPeerID: "sam")
        credit.reset()

        #expect(credit.isActive() == false)
        #expect(credit.friendsCredited == 0)
        #expect(credit.premiumUntil == nil)
        // And a previously credited friend can earn again after a wipe.
        #expect(credit.grant(forPeerID: "sam") == true)
    }
}

@MainActor
struct ReferralPremiumGateTests {

    private func gate() -> PremiumGate {
        let suite = "fixme.tests.\(UUID().uuidString)"
        return PremiumGate(
            subscriptions: SubscriptionService(),
            credit: ReferralCredit(defaults: UserDefaults(suiteName: suite)!)
        )
    }

    @Test func earnedCreditUnlocksPremiumFeatures() {
        let premium = gate()
        #expect(premium.isPremium == false)
        #expect(premium.canAddHabit(currentCount: PremiumGate.freeHabitLimit) == false)

        #expect(premium.grantReferralWeek(forPeerID: "sam") == true)

        #expect(premium.isPremium)
        #expect(premium.isOnReferralCreditOnly, "no purchase was made, so this is credit alone")
        #expect(premium.canAddHabit(currentCount: PremiumGate.freeHabitLimit))
        #expect(premium.isTemplateUnlocked(.fitness))
        #expect(premium.canRepairPastDay)
    }

    @Test func grantingTwiceForOneFriendReportsFalse() {
        let premium = gate()
        #expect(premium.grantReferralWeek(forPeerID: "sam") == true)
        #expect(premium.grantReferralWeek(forPeerID: "sam") == false)
        #expect(premium.friendsCredited == 1)
    }

    @Test func resetRevokesIt() {
        let premium = gate()
        premium.grantReferralWeek(forPeerID: "sam")
        premium.resetReferralCredit()
        #expect(premium.isPremium == false)
        #expect(premium.hasReferralPremium == false)
    }
}

/// The reward is only real if an actual pairing triggers it, and only fair if it fires
/// exactly once per friend. This covers the wiring between the two.
@MainActor
struct ReferralPairingHookTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    private func store(recording paired: PairingRecorder) -> FriendStore {
        FriendStore(modelContext: container.mainContext) { paired.record($0) }
    }

    private func card(_ name: String) -> IdentityCard {
        let key = Curve25519.Signing.PrivateKey()
        return PeerIdentity(peerID: UUID().uuidString, displayName: name, publicKey: key.publicKey).card
    }

    @Test func aNewPairingFiresTheHookOnce() throws {
        let paired = PairingRecorder()
        let store = store(recording: paired)

        let sam = card("Sam")
        try store.addFriend(from: sam, ownPeerID: "me", nearby: true)
        #expect(paired.peerIDs == [sam.peerID])
    }

    /// Re-pairing an existing friend refreshes their name and key but must not pay out
    /// again — that's the loop a free week would otherwise be farmed through.
    @Test func rePairingAnExistingFriendDoesNotFireAgain() throws {
        let paired = PairingRecorder()
        let store = store(recording: paired)

        let sam = card("Sam")
        try store.addFriend(from: sam, ownPeerID: "me", nearby: true)
        try store.addFriend(from: sam, ownPeerID: "me", nearby: false)
        try store.addFriend(from: sam, ownPeerID: "me", nearby: true)

        #expect(paired.peerIDs.count == 1, "only the first pairing with a given friend counts")
    }

    @Test func aRejectedSelfPairingPaysNothing() throws {
        let paired = PairingRecorder()
        let store = store(recording: paired)

        let me = card("Me")
        #expect(throws: PeerError.self) {
            try store.addFriend(from: me, ownPeerID: me.peerID, nearby: true)
        }
        #expect(paired.peerIDs.isEmpty)
    }
}

/// Collects the peer IDs the store reported as new pairings.
@MainActor
final class PairingRecorder {
    private(set) var peerIDs: [String] = []
    func record(_ peerID: String) { peerIDs.append(peerID) }
}
