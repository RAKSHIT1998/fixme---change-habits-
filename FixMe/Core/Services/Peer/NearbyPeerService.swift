@preconcurrency import MultipeerConnectivity
import Foundation
import Observation

/// Direct device-to-device connection over Wi-Fi and Bluetooth, with no server involved.
///
/// MultipeerConnectivity forms an encrypted session directly between two phones. It works
/// with no internet at all — but only while both devices are **nearby with the app open**,
/// which is the honest trade for having no infrastructure. For anything else, the app
/// falls back to signed `fixme://` links sent through the user's own messaging app.
@MainActor
@Observable
final class NearbyPeerService: NSObject {

    /// Bonjour service type: max 15 chars, lowercase letters, digits and hyphens.
    static let serviceType = "fixme-progress"

    enum State: Equatable {
        case idle
        case browsing
        case connecting(String)
        case connected(String)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var discoveredPeers: [MCPeerID] = []
    /// Cards received from peers this session, awaiting the user's confirmation to add.
    private(set) var pendingCards: [IdentityCard] = []
    private(set) var lastError: String?

    /// Envelopes received over a live session; the UI drains these into `FriendStore`.
    private(set) var inbox: [SignedEnvelope] = []

    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var localPeerID: MCPeerID?
    private var identity: PeerIdentity?

    // MARK: - Lifecycle

    /// Starts advertising and browsing. Both run together so either side can initiate.
    func start(identity: PeerIdentity) {
        stop()
        self.identity = identity

        // MCPeerID display names are capped at 63 UTF-8 bytes.
        let name = String(identity.displayName.prefix(30))
        let peerID = MCPeerID(displayName: name.isEmpty ? "Fix Me user" : name)
        localPeerID = peerID

        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["pid": identity.peerID],
            serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        state = .browsing
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        discoveredPeers = []
        state = .idle
    }

    // MARK: - Connecting

    func invite(_ peer: MCPeerID) {
        guard let session, let browser else { return }
        state = .connecting(peer.displayName)
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    // MARK: - Sending

    /// Sends this device's pairing card to everyone currently connected.
    func sendIdentityCard(sign: (Data) throws -> Data) {
        guard let identity else { return }
        do {
            let envelope = try SignedEnvelope.make(
                identity.card, kind: .identityCard, identity: identity, sign: sign
            )
            try send(envelope)
        } catch {
            lastError = "Couldn't send your invite: \(error.localizedDescription)"
        }
    }

    func send(_ envelope: SignedEnvelope) throws {
        guard let session, !session.connectedPeers.isEmpty else { return }
        let data = try JSONEncoder.peer.encode(envelope)
        try session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    func clearInbox() { inbox = [] }
    func clearPendingCards() { pendingCards = [] }

    // MARK: - Receiving

    /// Processes one received message. Internal rather than private so the pairing
    /// security rules below can be tested without two physical devices.
    func handle(_ data: Data) {
        guard let envelope = try? JSONDecoder.peer.decode(SignedEnvelope.self, from: data) else { return }

        switch envelope.kind {
        case .identityCard:
            // A card is self-signed: it carries its own public key, so verify the
            // signature against the key inside it. That proves the sender holds the
            // matching private key — it does not prove who they are in real life, which
            // is why the user still has to confirm before the friend is added.
            guard let card = try? JSONDecoder.peer.decode(IdentityCard.self, from: envelope.body),
                  let key = card.publicKey,
                  envelope.isSignatureValid(using: key),
                  card.peerID == envelope.senderPeerID
            else {
                lastError = "Ignored an invite that failed verification."
                return
            }
            if !pendingCards.contains(card) { pendingCards.append(card) }

        case .progressUpdate:
            // Verified later against the stored friend key, in FriendStore.
            inbox.append(envelope)
        }
    }
}

// MARK: - MCSessionDelegate

extension NearbyPeerService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let name = peerID.displayName
        Task { @MainActor in
            switch state {
            case .connected: self.state = .connected(name)
            case .connecting: self.state = .connecting(name)
            case .notConnected:
                if case .connected = self.state { self.state = .browsing }
            @unknown default: break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in self.handle(data) }
    }

    nonisolated func session(_ s: MCSession, didReceive stream: InputStream, withName: String, fromPeer: MCPeerID) {}
    nonisolated func session(_ s: MCSession, didStartReceivingResourceWithName: String, fromPeer: MCPeerID, with: Progress) {}
    nonisolated func session(_ s: MCSession, didFinishReceivingResourceWithName: String, fromPeer: MCPeerID, at: URL?, withError: Error?) {}
}

// MARK: - Advertiser

extension NearbyPeerService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            // Accepting only forms the encrypted channel. Nothing is trusted or stored
            // until the user explicitly confirms the card that arrives over it.
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        Task { @MainActor in
            self.state = .failed(error.localizedDescription)
            self.lastError = "Couldn't make this device discoverable. Check that Local Network access is allowed."
        }
    }
}

// MARK: - Browser

extension NearbyPeerService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            if !self.discoveredPeers.contains(peerID) { self.discoveredPeers.append(peerID) }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.state = .failed(error.localizedDescription)
            self.lastError = "Couldn't look for nearby friends. Check that Local Network access is allowed."
        }
    }
}
