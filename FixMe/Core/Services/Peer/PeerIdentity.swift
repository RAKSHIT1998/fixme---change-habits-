import Foundation
import CryptoKit
import Security

/// This device's cryptographic identity.
///
/// The whole peer-to-peer design rests on this: with no server to vouch for anyone, the
/// only thing making a received progress update trustworthy is that it carries a
/// signature verifiable against the public key you got when you paired. The private key
/// never leaves the Keychain, and nothing here is ever transmitted except the public half.
struct PeerIdentity {
    let peerID: String          // stable, random — not tied to any personal identifier
    let displayName: String
    let publicKey: Curve25519.Signing.PublicKey

    /// The shareable half: what a friend stores about you when you pair.
    var card: IdentityCard {
        IdentityCard(
            peerID: peerID,
            displayName: displayName,
            publicKeyData: publicKey.rawRepresentation
        )
    }
}

/// The public identity exchanged during pairing. Deliberately tiny so it fits in a link.
struct IdentityCard: Codable, Hashable {
    let peerID: String
    let displayName: String
    let publicKeyData: Data

    var publicKey: Curve25519.Signing.PublicKey? {
        try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
    }
}

/// Owns this device's keypair, persisting the private key in the Keychain.
@MainActor
final class PeerIdentityStore {
    private static let keychainAccount = "fixme.peer.privatekey"
    private static let peerIDKey = "fixme.peer.id"
    private static let displayNameKey = "fixme.peer.displayName"
    /// Shown until the user tells us their name.
    static let placeholderName = "A Fix Me user"

    private var cachedKey: Curve25519.Signing.PrivateKey?

    /// Name shown to friends. Defaults to the device name and is user-editable.
    var displayName: String {
        get { UserDefaults.standard.string(forKey: Self.displayNameKey) ?? Self.placeholderName }
        set { UserDefaults.standard.set(newValue, forKey: Self.displayNameKey) }
    }

    var peerID: String {
        if let existing = UserDefaults.standard.string(forKey: Self.peerIDKey) { return existing }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: Self.peerIDKey)
        return generated
    }

    /// Loads the device key, generating and storing one on first use.
    func privateKey() -> Curve25519.Signing.PrivateKey {
        if let cachedKey { return cachedKey }

        if let data = Self.readKeychain(account: Self.keychainAccount),
           let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) {
            cachedKey = key
            return key
        }

        let key = Curve25519.Signing.PrivateKey()
        Self.writeKeychain(key.rawRepresentation, account: Self.keychainAccount)
        cachedKey = key
        return key
    }

    var identity: PeerIdentity {
        PeerIdentity(peerID: peerID, displayName: displayName, publicKey: privateKey().publicKey)
    }

    func sign(_ data: Data) throws -> Data {
        try privateKey().signature(for: data)
    }

    /// Destroys the device identity. Friends who paired with the old key can no longer
    /// verify anything signed by this device, which is the intended effect of a reset.
    func reset() {
        Self.deleteKeychain(account: Self.keychainAccount)
        UserDefaults.standard.removeObject(forKey: Self.peerIDKey)
        cachedKey = nil
    }

    // MARK: - Keychain

    private static func writeKeychain(_ data: Data, account: String) {
        deleteKeychain(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Never syncs to iCloud and never leaves this device, even in a backup.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func readKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func deleteKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
