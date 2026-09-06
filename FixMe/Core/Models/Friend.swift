import Foundation
import SwiftData
import CryptoKit

/// Someone you've paired with device-to-device.
///
/// There is no account behind a Friend — just a display name and the public key captured
/// when you paired. That key is the only thing that makes their later updates trustworthy.
@Model
final class Friend {
    @Attribute(.unique) var peerID: String
    var displayName: String
    var publicKeyData: Data
    var addedAt: Date
    var lastUpdateAt: Date?
    /// How the pairing happened, shown so the user can judge how much to trust it.
    var pairedNearby: Bool

    @Relationship(deleteRule: .cascade, inverse: \FriendUpdate.friend)
    var updates: [FriendUpdate] = []

    init(
        peerID: String,
        displayName: String,
        publicKeyData: Data,
        addedAt: Date = .now,
        lastUpdateAt: Date? = nil,
        pairedNearby: Bool = false
    ) {
        self.peerID = peerID
        self.displayName = displayName
        self.publicKeyData = publicKeyData
        self.addedAt = addedAt
        self.lastUpdateAt = lastUpdateAt
        self.pairedNearby = pairedNearby
    }

    var publicKey: Curve25519.Signing.PublicKey? {
        try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
    }

    var card: IdentityCard {
        IdentityCard(peerID: peerID, displayName: displayName, publicKeyData: publicKeyData)
    }
}

/// A verified progress update received from a friend.
@Model
final class FriendUpdate {
    @Attribute(.unique) var updateID: UUID
    var dayNumber: Int
    var totalDays: Int
    var completionPercent: Int
    var streak: Int
    var habitNames: [String]
    var message: String?
    var cleanDays: Int?
    var createdAt: Date
    var receivedAt: Date
    var friend: Friend?

    init(
        updateID: UUID,
        dayNumber: Int,
        totalDays: Int,
        completionPercent: Int,
        streak: Int,
        habitNames: [String],
        message: String?,
        cleanDays: Int?,
        createdAt: Date,
        receivedAt: Date = .now
    ) {
        self.updateID = updateID
        self.dayNumber = dayNumber
        self.totalDays = totalDays
        self.completionPercent = completionPercent
        self.streak = streak
        self.habitNames = habitNames
        self.message = message
        self.cleanDays = cleanDays
        self.createdAt = createdAt
        self.receivedAt = receivedAt
    }
}
