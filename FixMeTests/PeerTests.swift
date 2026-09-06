import Testing
import Foundation
import SwiftData
import CryptoKit
@testable import FixMe

/// With no server, the signature *is* the security model — so these tests carry the
/// weight that a backend's auth layer normally would.
@MainActor
struct PeerCryptoTests {

    /// Stands in for another person's device.
    private struct FakeDevice {
        let key = Curve25519.Signing.PrivateKey()
        let peerID = UUID().uuidString
        let name: String

        var identity: PeerIdentity {
            PeerIdentity(peerID: peerID, displayName: name, publicKey: key.publicKey)
        }
        func sign(_ data: Data) throws -> Data { try key.signature(for: data) }

        func update(message: String = "hi") throws -> SignedEnvelope {
            try SignedEnvelope.make(
                ProgressUpdatePayload(
                    displayName: name, dayNumber: 12, completionPercent: 80,
                    streak: 5, habitNames: ["Read"], message: message
                ),
                kind: .progressUpdate, identity: identity, sign: sign
            )
        }
    }

    @Test func signedPayloadRoundTrips() throws {
        let sam = FakeDevice(name: "Sam")
        let envelope = try sam.update(message: "Day 12 done")

        #expect(envelope.isSignatureValid(using: sam.key.publicKey))
        let decoded = try envelope.decode(ProgressUpdatePayload.self, verifiedWith: sam.key.publicKey)
        #expect(decoded.message == "Day 12 done")
        #expect(decoded.streak == 5)
    }

    @Test func aDifferentKeyCannotVerify() throws {
        let sam = FakeDevice(name: "Sam")
        let impostor = FakeDevice(name: "Not Sam")
        let envelope = try sam.update()

        #expect(!envelope.isSignatureValid(using: impostor.key.publicKey))
    }

    /// Tampering with the body must invalidate the signature.
    @Test func editingTheBodyBreaksVerification() throws {
        let sam = FakeDevice(name: "Sam")
        let real = try sam.update(message: "80%")

        let forgedBody = try JSONEncoder.peer.encode(
            ProgressUpdatePayload(
                displayName: "Sam", dayNumber: 12, completionPercent: 100,
                streak: 99, habitNames: [], message: "100%"
            )
        )
        let forged = SignedEnvelope(
            senderPeerID: real.senderPeerID, kind: real.kind,
            body: forgedBody, sentAt: real.sentAt, signature: real.signature
        )

        #expect(!forged.isSignatureValid(using: sam.key.publicKey))
    }

    /// The signature covers the sender id too, so a genuine update can't be re-attributed.
    @Test func reattributingASenderBreaksVerification() throws {
        let sam = FakeDevice(name: "Sam")
        let real = try sam.update()

        let moved = SignedEnvelope(
            senderPeerID: "someone-else", kind: real.kind,
            body: real.body, sentAt: real.sentAt, signature: real.signature
        )

        #expect(!moved.isSignatureValid(using: sam.key.publicKey))
    }

    @Test func decodeRefusesUnverifiedPayloads() throws {
        let sam = FakeDevice(name: "Sam")
        let impostor = FakeDevice(name: "Impostor")
        let envelope = try sam.update()

        #expect(throws: PeerError.self) {
            try envelope.decode(ProgressUpdatePayload.self, verifiedWith: impostor.key.publicKey)
        }
    }
}

@MainActor
struct PeerLinkTests {

    @Test func inviteLinkRoundTrips() throws {
        let key = Curve25519.Signing.PrivateKey()
        let card = IdentityCard(
            peerID: UUID().uuidString, displayName: "Sam",
            publicKeyData: key.publicKey.rawRepresentation
        )

        let url = try PeerLink.inviteURL(for: card)
        #expect(url.scheme == "fixme")

        guard case .invite(let decoded) = try PeerLink.parse(url) else {
            Issue.record("expected an invite"); return
        }
        #expect(decoded == card)
        #expect(decoded.publicKey != nil)
    }

    @Test func updateLinkRoundTrips() throws {
        let key = Curve25519.Signing.PrivateKey()
        let identity = PeerIdentity(peerID: "p1", displayName: "Sam", publicKey: key.publicKey)
        let envelope = try SignedEnvelope.make(
            ProgressUpdatePayload(displayName: "Sam", dayNumber: 3, completionPercent: 50, streak: 3),
            kind: .progressUpdate, identity: identity, sign: { try key.signature(for: $0) }
        )

        let url = try PeerLink.updateURL(for: envelope)
        guard case .update(let decoded) = try PeerLink.parse(url) else {
            Issue.record("expected an update"); return
        }
        // Must survive base64url + JSON without breaking the signature.
        #expect(decoded.isSignatureValid(using: key.publicKey))
    }

    @Test func junkLinksAreRejected() {
        for string in ["https://example.com", "fixme://nonsense", "fixme://add-friend", "fixme://add-friend?d=%%%"] {
            let url = URL(string: string)
            #expect(url == nil || (try? PeerLink.parse(url!)) == nil)
        }
    }

    @Test func base64URLSurvivesRoundTrip() {
        let data = Data((0..<256).map { UInt8($0) })
        let encoded = data.base64URLEncodedString()
        #expect(!encoded.contains("+") && !encoded.contains("/") && !encoded.contains("="))
        #expect(Data(base64URLEncoded: encoded) == data)
    }
}

@MainActor
struct FriendStoreTests {
    let container: ModelContainer
    let store: FriendStore

    init() throws {
        container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        store = FriendStore(modelContext: container.mainContext)
    }

    private func device(_ name: String) -> (key: Curve25519.Signing.PrivateKey, identity: PeerIdentity) {
        let key = Curve25519.Signing.PrivateKey()
        return (key, PeerIdentity(peerID: UUID().uuidString, displayName: name, publicKey: key.publicKey))
    }

    private func update(from d: (key: Curve25519.Signing.PrivateKey, identity: PeerIdentity)) throws -> SignedEnvelope {
        try SignedEnvelope.make(
            ProgressUpdatePayload(
                displayName: d.identity.displayName, dayNumber: 5,
                completionPercent: 60, streak: 2, habitNames: ["Read"]
            ),
            kind: .progressUpdate, identity: d.identity, sign: { try d.key.signature(for: $0) }
        )
    }

    @Test func pairingThenReceivingWorksEndToEnd() throws {
        let sam = device("Sam")
        try store.addFriend(from: sam.identity.card, ownPeerID: "me", nearby: true)

        let stored = try #require(try store.receive(update(from: sam)))
        #expect(stored.friend?.displayName == "Sam")
        #expect(stored.completionPercent == 60)
        #expect(store.allUpdates().count == 1)
    }

    /// An update from someone you never paired with must not appear in the feed.
    @Test func updatesFromStrangersAreRejected() throws {
        let stranger = device("Stranger")
        #expect(throws: PeerError.self) { try store.receive(update(from: stranger)) }
        #expect(store.allUpdates().isEmpty)
    }

    /// Pairing with Sam must not let an impostor sign as Sam.
    @Test func impostorUsingAFriendsPeerIDIsRejected() throws {
        let sam = device("Sam")
        try store.addFriend(from: sam.identity.card, ownPeerID: "me", nearby: true)

        // Same peerID, different key.
        let impostorKey = Curve25519.Signing.PrivateKey()
        let impostor = PeerIdentity(
            peerID: sam.identity.peerID, displayName: "Sam", publicKey: impostorKey.publicKey
        )
        let forged = try SignedEnvelope.make(
            ProgressUpdatePayload(displayName: "Sam", dayNumber: 99, completionPercent: 100, streak: 99),
            kind: .progressUpdate, identity: impostor, sign: { try impostorKey.signature(for: $0) }
        )

        #expect(throws: PeerError.self) { try store.receive(forged) }
        #expect(store.allUpdates().isEmpty)
    }

    /// Links get forwarded and sessions reconnect, so the same update arrives twice.
    @Test func duplicateUpdatesAreIgnored() throws {
        let sam = device("Sam")
        try store.addFriend(from: sam.identity.card, ownPeerID: "me", nearby: true)
        let envelope = try update(from: sam)

        #expect(try store.receive(envelope) != nil)
        #expect(try store.receive(envelope) == nil)
        #expect(store.allUpdates().count == 1)
    }

    @Test func youCannotAddYourself() throws {
        let me = device("Me")
        #expect(throws: PeerError.self) {
            try store.addFriend(from: me.identity.card, ownPeerID: me.identity.peerID, nearby: false)
        }
    }

    /// Re-pairing after a reinstall replaces the key rather than creating a duplicate.
    @Test func rePairingUpdatesTheExistingFriend() throws {
        let sam = device("Sam")
        try store.addFriend(from: sam.identity.card, ownPeerID: "me", nearby: false)

        let newKey = Curve25519.Signing.PrivateKey()
        let renamed = IdentityCard(
            peerID: sam.identity.peerID, displayName: "Samantha",
            publicKeyData: newKey.publicKey.rawRepresentation
        )
        try store.addFriend(from: renamed, ownPeerID: "me", nearby: true)

        #expect(store.allFriends().count == 1)
        #expect(store.allFriends().first?.displayName == "Samantha")
        #expect(store.allFriends().first?.pairedNearby == true)
    }

    @Test func removingAFriendDeletesTheirUpdates() throws {
        let sam = device("Sam")
        let friend = try store.addFriend(from: sam.identity.card, ownPeerID: "me", nearby: true)
        _ = try store.receive(update(from: sam))
        #expect(store.allUpdates().count == 1)

        store.remove(friend)

        #expect(store.allFriends().isEmpty)
        #expect(store.allUpdates().isEmpty)
    }
}

/// Pairing over a nearby session is where impersonation would happen, so its rules are
/// tested directly. The radio can't be exercised without two devices, but the decision
/// logic that runs on every received message can.
@MainActor
struct NearbyPairingTests {

    private func card(for key: Curve25519.Signing.PrivateKey, peerID: String, name: String) -> IdentityCard {
        IdentityCard(peerID: peerID, displayName: name, publicKeyData: key.publicKey.rawRepresentation)
    }

    private func envelope(
        card: IdentityCard,
        signedBy key: Curve25519.Signing.PrivateKey,
        senderPeerID: String
    ) throws -> Data {
        let identity = PeerIdentity(
            peerID: senderPeerID, displayName: card.displayName, publicKey: key.publicKey
        )
        let signed = try SignedEnvelope.make(
            card, kind: .identityCard, identity: identity, sign: { try key.signature(for: $0) }
        )
        return try JSONEncoder.peer.encode(signed)
    }

    @Test func aValidCardBecomesPending() throws {
        let service = NearbyPeerService()
        let key = Curve25519.Signing.PrivateKey()
        let peerID = UUID().uuidString
        let sam = card(for: key, peerID: peerID, name: "Sam")

        service.handle(try envelope(card: sam, signedBy: key, senderPeerID: peerID))

        #expect(service.pendingCards.count == 1)
        #expect(service.pendingCards.first?.displayName == "Sam")
    }

    /// A card must be signed by the key inside it. Otherwise anyone could broadcast a
    /// card containing someone else's public key and be added under their name.
    @Test func aCardSignedByAnotherKeyIsRejected() throws {
        let service = NearbyPeerService()
        let samKey = Curve25519.Signing.PrivateKey()
        let attackerKey = Curve25519.Signing.PrivateKey()
        let peerID = UUID().uuidString
        let sam = card(for: samKey, peerID: peerID, name: "Sam")

        service.handle(try envelope(card: sam, signedBy: attackerKey, senderPeerID: peerID))

        #expect(service.pendingCards.isEmpty)
    }

    /// The card's own peerID must match the envelope's sender, or the two identities
    /// could be mixed to attribute a card to a different peer.
    @Test func aCardWhosePeerIDDoesNotMatchTheSenderIsRejected() throws {
        let service = NearbyPeerService()
        let key = Curve25519.Signing.PrivateKey()
        let sam = card(for: key, peerID: "claimed-peer", name: "Sam")

        service.handle(try envelope(card: sam, signedBy: key, senderPeerID: "actual-different-peer"))

        #expect(service.pendingCards.isEmpty)
    }

    /// Updates aren't verified here — that happens in FriendStore against the stored key —
    /// so they queue for the UI to drain.
    @Test func progressUpdatesQueueInTheInbox() throws {
        let service = NearbyPeerService()
        let key = Curve25519.Signing.PrivateKey()
        let identity = PeerIdentity(peerID: "p", displayName: "Sam", publicKey: key.publicKey)
        let signed = try SignedEnvelope.make(
            ProgressUpdatePayload(displayName: "Sam", dayNumber: 1, completionPercent: 10, streak: 1),
            kind: .progressUpdate, identity: identity, sign: { try key.signature(for: $0) }
        )

        service.handle(try JSONEncoder.peer.encode(signed))

        #expect(service.inbox.count == 1)
        #expect(service.pendingCards.isEmpty)
    }

    @Test func malformedDataIsIgnoredWithoutCrashing() {
        let service = NearbyPeerService()
        service.handle(Data("not json".utf8))
        service.handle(Data())
        #expect(service.pendingCards.isEmpty)
        #expect(service.inbox.isEmpty)
    }

    @Test func theSameCardIsNotQueuedTwice() throws {
        let service = NearbyPeerService()
        let key = Curve25519.Signing.PrivateKey()
        let peerID = UUID().uuidString
        let sam = card(for: key, peerID: peerID, name: "Sam")
        let data = try envelope(card: sam, signedBy: key, senderPeerID: peerID)

        service.handle(data)
        service.handle(data)

        #expect(service.pendingCards.count == 1)
    }
}
