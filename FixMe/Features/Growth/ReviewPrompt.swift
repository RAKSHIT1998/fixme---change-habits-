import Foundation

/// When to ask for an App Store rating.
///
/// Ratings are the largest organic channel a habit app has — they feed App Store ranking,
/// which feeds installs — and the app currently never asks. But iOS only honours three
/// prompts per year and silently swallows the rest, so the ones spent badly are gone.
/// That makes *when* the entire feature.
///
/// The rules below all come from the same idea: ask someone who is currently pleased with
/// the app, and never ask twice for the same answer.
///
/// - **Only after a good day.** A strong score or a milestone. Asking on the day someone
///   broke a 40-day streak is how an app earns one star.
/// - **Not in week one.** Nobody can rate a 90-day app on day two, and it burns a prompt.
/// - **Rarely.** Far below Apple's three-a-year ceiling, so the prompts that do fire land
///   on genuinely good days rather than the first three days that qualify.
/// - **Once per version.** Someone who dismissed the prompt already answered.
struct ReviewPrompt {
    static let earliestDay = 7
    static let goodDayScore = 80
    static let daysBetweenAsks = 120

    private enum Key {
        static let lastAskedAt = "fixme.review.lastAskedAt"
        static let lastAskedVersion = "fixme.review.lastAskedVersion"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastAskedAt: Date? {
        let raw = defaults.double(forKey: Key.lastAskedAt)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    var lastAskedVersion: String? { defaults.string(forKey: Key.lastAskedVersion) }

    /// Whether the moment that just happened is worth spending a prompt on.
    func shouldAsk(
        dayNumber: Int,
        dailyScore: Int,
        appVersion: String,
        now: Date = .now
    ) -> Bool {
        guard dayNumber >= Self.earliestDay else { return false }

        // A milestone is worth asking on even if the score was middling — reaching day 30
        // at all is the achievement, not the tick count on the day itself.
        let isGoodMoment = dailyScore >= Self.goodDayScore || Milestone.milestone(for: dayNumber) != nil
        guard isGoodMoment else { return false }

        guard lastAskedVersion != appVersion else { return false }

        if let lastAskedAt {
            let daysSince = now.timeIntervalSince(lastAskedAt) / 86_400
            guard daysSince >= Double(Self.daysBetweenAsks) else { return false }
        }
        return true
    }

    func recordAsk(appVersion: String, now: Date = .now) {
        defaults.set(now.timeIntervalSince1970, forKey: Key.lastAskedAt)
        defaults.set(appVersion, forKey: Key.lastAskedVersion)
    }

    func reset() {
        defaults.removeObject(forKey: Key.lastAskedAt)
        defaults.removeObject(forKey: Key.lastAskedVersion)
    }

    static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
