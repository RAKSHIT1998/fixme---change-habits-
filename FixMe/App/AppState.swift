import SwiftUI
import Observation

/// App-wide, lightweight UI state. Persisted flags live in `UserDefaults`;
/// durable user/journey data lives in SwiftData (see `Core/Models`).
@Observable
final class AppState {
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.onboarded) }
    }

    var selectedTab: MainTab = .today

    /// Debug-only: opens the Social tab on a given section for demos and screenshots.
    var initialSocialSection: String?

    /// Debug-only: presents the how-to guide straight away.
    var showGuideOnLaunch = false

    /// Set true while the user is mid-onboarding to preview journey math live.
    var draftCommitmentLevel: CommitmentLevel = .committed

    private enum Keys {
        static let onboarded = "fixme.hasCompletedOnboarding"
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.onboarded)
        #if DEBUG
        // `-FixMeTab social` opens straight to a tab — handy for demos and screenshots.
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-FixMeTab"), index + 1 < args.count,
           let tab = MainTab(rawValue: args[index + 1]) {
            self.selectedTab = tab
        }
        if let index = args.firstIndex(of: "-FixMeSocialSection"), index + 1 < args.count {
            self.initialSocialSection = args[index + 1]
        }
        self.showGuideOnLaunch = args.contains("-FixMeShowGuide")
        #endif
    }
}

enum MainTab: String, CaseIterable, Identifiable {
    case today, journey, explore, social, profile
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .journey: return "Journey"
        case .explore: return "Explore"
        case .social: return "Social"
        case .profile: return "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "sun.max.fill"
        case .journey: return "map.fill"
        case .explore: return "sparkles"
        case .social: return "person.2.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
}
