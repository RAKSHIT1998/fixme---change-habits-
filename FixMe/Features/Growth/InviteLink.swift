import Foundation

/// The app's public web address. One definition, because it appears in invite links, the
/// reel's end card copy and the support screen, and a stale copy in any of them is a dead
/// link in front of a stranger.
enum FixMeSite {
    static let base = URL(string: "https://rakshit1998.github.io/fixme---change-habits-")!

    static var support: URL { base.appendingPathComponent("support.html") }
    static var privacy: URL { base.appendingPathComponent("privacy.html") }
    static var terms: URL { base.appendingPathComponent("terms.html") }
    static var invite: URL { base.appendingPathComponent("i.html") }
}

/// Turns an in-app deep link into something that survives being sent to a stranger.
///
/// `fixme://` links have two failure modes that cost every invite sent to someone who
/// isn't already a user. They do nothing at all when the app isn't installed — Safari just
/// errors — and most messaging apps (WhatsApp and Instagram among them) won't linkify an
/// unknown scheme, so the invite arrives as dead grey text nobody can tap.
///
/// Wrapping the same payload in an `https://` link fixes both: every messenger makes it
/// tappable, and the page it lands on bounces straight into the app when it's installed,
/// or shows the App Store when it isn't. The payload is unchanged and still signed —
/// this is an envelope, not a new trust model.
///
/// The page does the bouncing in JavaScript rather than through a universal link, because
/// universal links need an apple-app-site-association file served from the domain root,
/// and the app is currently hosted on a GitHub Pages subpath. Worth revisiting when the
/// custom domain lands — it would drop the Safari flash.
enum InviteLink {
    /// Wraps `fixme://add-friend?d=…` as `…/i.html?k=add-friend&d=…`.
    static func web(for deepLink: URL) -> URL {
        guard let host = deepLink.host,
              var components = URLComponents(url: FixMeSite.invite, resolvingAgainstBaseURL: false)
        else { return deepLink }

        var items = [URLQueryItem(name: "k", value: host)]
        items.append(contentsOf: URLComponents(url: deepLink, resolvingAgainstBaseURL: false)?.queryItems ?? [])
        components.queryItems = items
        return components.url ?? deepLink
    }

    /// A referral link carries only the code — there is nothing to sign and nothing
    /// private in it.
    static func referral(code: String) -> URL {
        guard var components = URLComponents(url: FixMeSite.invite, resolvingAgainstBaseURL: false)
        else { return FixMeSite.base }
        components.queryItems = [URLQueryItem(name: "c", value: code)]
        return components.url ?? FixMeSite.base
    }

    /// Recovers the original deep link from a wrapped web link, so a pasted `https://`
    /// invite works exactly like a pasted `fixme://` one.
    static func deepLink(from webURL: URL) -> URL? {
        guard let components = URLComponents(url: webURL, resolvingAgainstBaseURL: false),
              let items = components.queryItems,
              let kind = items.first(where: { $0.name == "k" })?.value,
              let payload = items.first(where: { $0.name == "d" })?.value
        else { return nil }

        var deep = URLComponents()
        deep.scheme = PeerLink.scheme
        deep.host = kind
        deep.queryItems = [URLQueryItem(name: "d", value: payload)]
        return deep.url
    }
}
