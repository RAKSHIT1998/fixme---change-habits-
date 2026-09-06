import Foundation
import CryptoKit

enum PayloadKind: String, Codable {
    case identityCard
    case progressUpdate
}

/// A progress update as sent to a friend.
///
/// Only what the user explicitly chose to share travels — there is no "sync everything"
/// path, because with no server the payload is the entire privacy boundary.
struct ProgressUpdatePayload: Codable, Hashable {
    let updateID: UUID
    let displayName: String
    let dayNumber: Int
    let totalDays: Int
    let completionPercent: Int
    let streak: Int
    let habitNames: [String]
    let message: String?
    /// Days clean, when the sender chose to share a quit habit. Nil otherwise.
    let cleanDays: Int?
    let createdAt: Date

    init(
        updateID: UUID = UUID(),
        displayName: String,
        dayNumber: Int,
        totalDays: Int = 90,
        completionPercent: Int,
        streak: Int,
        habitNames: [String] = [],
        message: String? = nil,
        cleanDays: Int? = nil,
        createdAt: Date = .now
    ) {
        self.updateID = updateID
        self.displayName = displayName
        self.dayNumber = dayNumber
        self.totalDays = totalDays
        self.completionPercent = completionPercent
        self.streak = streak
        self.habitNames = habitNames
        self.message = message
        self.cleanDays = cleanDays
        self.createdAt = createdAt
    }
}

/// A payload plus proof of who produced it.
///
/// Without a server there is no authority to ask "is this really from Sam?", so every
/// message is signed with the sender's device key and verified against the public key
/// captured at pairing. An unverifiable envelope is discarded rather than shown.
struct SignedEnvelope: Codable {
    let senderPeerID: String
    let kind: PayloadKind
    let body: Data
    let sentAt: Date
    let signature: Data

    /// Bytes the signature covers. Every field that carries meaning is included — signing
    /// only `body` would let anyone re-attribute a genuine update to a different sender.
    static func signingBytes(senderPeerID: String, kind: PayloadKind, body: Data, sentAt: Date) -> Data {
        var data = Data()
        data.append(Data(senderPeerID.utf8))
        data.append(Data(kind.rawValue.utf8))
        data.append(body)
        withUnsafeBytes(of: sentAt.timeIntervalSince1970.bitPattern.bigEndian) { data.append(contentsOf: $0) }
        return data
    }

    static func make<T: Encodable>(
        _ value: T,
        kind: PayloadKind,
        identity: PeerIdentity,
        sign: (Data) throws -> Data,
        sentAt: Date = .now
    ) throws -> SignedEnvelope {
        let body = try JSONEncoder.peer.encode(value)
        let bytes = signingBytes(senderPeerID: identity.peerID, kind: kind, body: body, sentAt: sentAt)
        return SignedEnvelope(
            senderPeerID: identity.peerID,
            kind: kind,
            body: body,
            sentAt: sentAt,
            signature: try sign(bytes)
        )
    }

    /// True only when the signature was produced by the holder of `publicKey`.
    func isSignatureValid(using publicKey: Curve25519.Signing.PublicKey) -> Bool {
        let bytes = Self.signingBytes(senderPeerID: senderPeerID, kind: kind, body: body, sentAt: sentAt)
        return publicKey.isValidSignature(signature, for: bytes)
    }

    /// Decodes the body *after* verifying it. There is no unchecked decode on purpose.
    func decode<T: Decodable>(_ type: T.Type, verifiedWith publicKey: Curve25519.Signing.PublicKey) throws -> T {
        guard isSignatureValid(using: publicKey) else { throw PeerError.signatureInvalid }
        return try JSONDecoder.peer.decode(type, from: body)
    }
}

enum PeerError: LocalizedError {
    case signatureInvalid
    case unknownSender
    case malformedLink
    case selfPairing

    var errorDescription: String? {
        switch self {
        case .signatureInvalid: return "That update couldn't be verified, so it wasn't added."
        case .unknownSender: return "That's from someone you haven't added as a friend yet."
        case .malformedLink: return "That link doesn't look like a Fix Me invite."
        case .selfPairing: return "That's your own invite link."
        }
    }
}

extension JSONEncoder {
    /// Fixed configuration on both sides — a differing date strategy would silently break
    /// signature verification between app versions.
    static let peer: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let peer: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
}
