import Foundation

/// Encodes pairing invites and progress updates as `fixme://` links.
///
/// This is the "any distance, still no server" path: a link can be sent through iMessage,
/// WhatsApp, email — whatever the two people already use. Those apps are only a transport;
/// nothing is stored anywhere Fix Me controls, and no account exists to look anyone up in.
///
/// The scheme itself is deliberately not a universal link: those require an
/// apple-app-site-association file served from a domain root, which the GitHub Pages
/// subpath can't provide. `InviteLink` wraps these in an https:// page instead, which is
/// what actually gets sent to other people — a bare fixme:// link is unclickable in most
/// messaging apps and dead for anyone without the app installed.
enum PeerLink {
    static let scheme = "fixme"

    enum Parsed {
        case invite(IdentityCard)
        case update(SignedEnvelope)
    }

    // MARK: - Building

    static func inviteURL(for card: IdentityCard) throws -> URL {
        try url(host: "add-friend", value: card)
    }

    static func updateURL(for envelope: SignedEnvelope) throws -> URL {
        try url(host: "update", value: envelope)
    }

    private static func url<T: Encodable>(host: String, value: T) throws -> URL {
        let data = try JSONEncoder.peer.encode(value)
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: "d", value: data.base64URLEncodedString())]
        guard let url = components.url else { throw PeerError.malformedLink }
        return url
    }

    // MARK: - Parsing

    /// Accepts both the raw `fixme://` link and the `https://` invite-page link that
    /// wraps it (see `InviteLink`), so a pasted invite works whichever form it arrived in.
    static func parse(_ url: URL) throws -> Parsed {
        if url.scheme != scheme, let unwrapped = InviteLink.deepLink(from: url) {
            return try parse(unwrapped)
        }
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encoded = components.queryItems?.first(where: { $0.name == "d" })?.value,
              let data = Data(base64URLEncoded: encoded)
        else { throw PeerError.malformedLink }

        switch url.host {
        case "add-friend":
            return .invite(try JSONDecoder.peer.decode(IdentityCard.self, from: data))
        case "update":
            return .update(try JSONDecoder.peer.decode(SignedEnvelope.self, from: data))
        default:
            throw PeerError.malformedLink
        }
    }
}

extension Data {
    /// Base64url — safe inside a URL query without percent-encoding surprises.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var value = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while value.count % 4 != 0 { value.append("=") }
        guard let data = Data(base64Encoded: value) else { return nil }
        self = data
    }
}
