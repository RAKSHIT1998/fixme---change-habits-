import Foundation

/// Premium earned by pairing with a friend, stored on the device.
///
/// The app has been promising "you both get a free week" since the referral screen
/// shipped, and nothing anywhere granted one — `referralsConverted` was never incremented
/// by any code path. This makes the promise real.
///
/// It has to work without a server, which rules out verifying anything. Two limits keep
/// that from turning into unlimited free premium, and both are stated in the UI rather
/// than hidden:
///
/// - **Once per friend.** Credit is keyed on the friend's peer ID, so unpairing and
///   re-pairing the same person earns nothing the second time.
/// - **Capped.** `maxEarnedDays` total, ever. Someone determined to farm weeks with spare
///   devices gets a month and then stops, which is a cheap enough ceiling to accept in
///   exchange for having no accounts to police.
///
/// Anyone willing to work harder than that would have found the free tier perfectly usable
/// anyway — it keeps the entire core loop.
struct ReferralCredit {
    static let daysPerFriend = 7
    static let maxEarnedDays = 28

    private enum Key {
        static let premiumUntil = "fixme.referral.premiumUntil"
        static let creditedPeers = "fixme.referral.creditedPeerIDs"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Reading

    /// When earned premium runs out, or nil if none was ever earned.
    var premiumUntil: Date? {
        let raw = defaults.double(forKey: Key.premiumUntil)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    var creditedPeerIDs: [String] {
        defaults.stringArray(forKey: Key.creditedPeers) ?? []
    }

    var friendsCredited: Int { creditedPeerIDs.count }

    var earnedDays: Int { min(friendsCredited * Self.daysPerFriend, Self.maxEarnedDays) }

    var hasReachedCap: Bool { earnedDays >= Self.maxEarnedDays }

    func isActive(now: Date = .now) -> Bool {
        guard let premiumUntil else { return false }
        return premiumUntil > now
    }

    /// Whole days left, rounded up — someone with four hours left has "1 day", not "0".
    func daysRemaining(now: Date = .now) -> Int {
        guard let premiumUntil, premiumUntil > now else { return 0 }
        return Int(ceil(premiumUntil.timeIntervalSince(now) / 86_400))
    }

    // MARK: - Writing

    /// Grants a week for pairing with `peerID`. Returns false when this friend has already
    /// been credited or the lifetime cap is reached, so callers can stay quiet rather than
    /// claiming a reward that wasn't given.
    @discardableResult
    func grant(forPeerID peerID: String, now: Date = .now) -> Bool {
        var credited = creditedPeerIDs
        guard !credited.contains(peerID), !hasReachedCap else { return false }

        credited.append(peerID)
        defaults.set(credited, forKey: Key.creditedPeers)

        // Extend from whichever is later, so pairing with a second friend during an active
        // week adds to it instead of overwriting it.
        let start = max(now, premiumUntil ?? now)
        let extended = start.addingTimeInterval(Double(Self.daysPerFriend) * 86_400)
        defaults.set(extended.timeIntervalSince1970, forKey: Key.premiumUntil)
        return true
    }

    /// Cleared by "Delete my data" along with everything else.
    func reset() {
        defaults.removeObject(forKey: Key.premiumUntil)
        defaults.removeObject(forKey: Key.creditedPeers)
    }
}
