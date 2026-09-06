import Foundation
import SwiftData

/// Stores friends and their updates, and is the single place an incoming payload is
/// allowed through.
///
/// Every write path here verifies a signature first. Anything unverifiable is rejected
/// rather than stored, because in a peer-to-peer design there is no server to blame and
/// no second chance to catch a forged update once it's in the feed.
@MainActor
struct FriendStore {
    let modelContext: ModelContext

    /// Called once with the peer ID when a pairing is genuinely new — not on a re-pair or
    /// a name refresh. This is the single choke point where "a new friend was added"
    /// is actually known, which is exactly what the referral reward depends on.
    var onNewPairing: (@MainActor (String) -> Void)?

    // MARK: - Friends

    func allFriends() -> [Friend] {
        let descriptor = FetchDescriptor<Friend>(sortBy: [SortDescriptor(\.displayName)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func friend(peerID: String) -> Friend? {
        allFriends().first { $0.peerID == peerID }
    }

    /// Adds (or refreshes) a friend from a pairing card.
    /// Re-pairing updates the display name but deliberately also updates the key: a friend
    /// who reinstalled has a new keypair, and refusing it would silently break sync.
    @discardableResult
    func addFriend(from card: IdentityCard, ownPeerID: String, nearby: Bool) throws -> Friend {
        guard card.peerID != ownPeerID else { throw PeerError.selfPairing }
        guard card.publicKey != nil else { throw PeerError.malformedLink }

        if let existing = friend(peerID: card.peerID) {
            existing.displayName = card.displayName
            existing.publicKeyData = card.publicKeyData
            existing.pairedNearby = existing.pairedNearby || nearby
            try modelContext.save()
            return existing
        }

        let friend = Friend(
            peerID: card.peerID,
            displayName: card.displayName,
            publicKeyData: card.publicKeyData,
            pairedNearby: nearby
        )
        modelContext.insert(friend)
        try modelContext.save()
        onNewPairing?(card.peerID)
        return friend
    }

    func remove(_ friend: Friend) {
        modelContext.delete(friend)
        try? modelContext.save()
    }

    // MARK: - Updates

    func allUpdates() -> [FriendUpdate] {
        let descriptor = FetchDescriptor<FriendUpdate>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Verifies and stores an incoming envelope.
    ///
    /// Returns the stored update, or nil when it's a duplicate we already have — resends
    /// are expected, since a link can be forwarded or a nearby session can reconnect.
    @discardableResult
    func receive(_ envelope: SignedEnvelope) throws -> FriendUpdate? {
        guard envelope.kind == .progressUpdate else { throw PeerError.malformedLink }
        guard let friend = friend(peerID: envelope.senderPeerID) else { throw PeerError.unknownSender }
        guard let key = friend.publicKey else { throw PeerError.signatureInvalid }

        // Throws `.signatureInvalid` if the payload was altered or isn't from this friend.
        let payload = try envelope.decode(ProgressUpdatePayload.self, verifiedWith: key)

        if allUpdates().contains(where: { $0.updateID == payload.updateID }) {
            return nil
        }

        let update = FriendUpdate(
            updateID: payload.updateID,
            dayNumber: payload.dayNumber,
            totalDays: payload.totalDays,
            completionPercent: payload.completionPercent,
            streak: payload.streak,
            habitNames: payload.habitNames,
            message: payload.message,
            cleanDays: payload.cleanDays,
            createdAt: payload.createdAt
        )
        update.friend = friend
        friend.updates.append(update)
        friend.lastUpdateAt = payload.createdAt
        // A friend can rename themselves between updates.
        if !payload.displayName.isEmpty { friend.displayName = payload.displayName }

        modelContext.insert(update)
        try modelContext.save()
        return update
    }
}
