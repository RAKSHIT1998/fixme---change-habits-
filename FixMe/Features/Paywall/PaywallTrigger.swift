import Foundation

/// Where a paywall was opened from. Contextual paywalls convert far better than one
/// generic screen, so each entry point gets copy that speaks to the thing the user was
/// *just* trying to do.
enum PaywallTrigger: String, Identifiable {
    case onboardingComplete
    case habitLimit
    case aiVerificationQuota
    case premiumTemplate
    case streakRepair
    case advancedInsights
    case settings

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .onboardingComplete: return "Give yourself the best shot."
        case .habitLimit: return "Room for every habit."
        case .aiVerificationQuota: return "Keep proving it."
        case .premiumTemplate: return "Make it look as good as it felt."
        case .streakRepair: return "Don't lose your streak."
        case .advancedInsights: return "See what's actually working."
        case .settings: return "Fix Me Premium"
        }
    }

    var subheadline: String {
        switch self {
        case .onboardingComplete:
            return "People who track every habit from day one are the ones still here on day 90."
        case .habitLimit:
            return "Free covers \(PremiumGate.freeHabitLimit) habits. Premium covers the whole routine."
        case .aiVerificationQuota:
            return "You've used your free verifications this week. Premium never runs out."
        case .premiumTemplate:
            return "Unlock every share template, in every format."
        case .streakRepair:
            return "Premium lets you repair a missed day and keep your momentum."
        case .advancedInsights:
            return "Trends, patterns and the habits quietly carrying your progress."
        case .settings:
            return "Everything unlocked, for the full 90 days and beyond."
        }
    }

    /// The bullet we visually emphasize for this trigger.
    var emphasizedFeature: PremiumFeature {
        switch self {
        case .onboardingComplete, .settings: return .unlimitedHabits
        case .habitLimit: return .unlimitedHabits
        case .aiVerificationQuota: return .unlimitedAIVerification
        case .premiumTemplate: return .premiumShareTemplates
        case .streakRepair: return .streakRepair
        case .advancedInsights: return .advancedInsights
        }
    }

    /// Onboarding's paywall is dismissible but presented full-screen; contextual ones are sheets.
    var isFullScreen: Bool { self == .onboardingComplete }
}

extension PremiumFeature {
    var title: String {
        switch self {
        case .unlimitedHabits: return "Unlimited habits"
        case .unlimitedAIVerification: return "Unlimited AI verification"
        case .premiumShareTemplates: return "Every share template"
        case .advancedInsights: return "Advanced insights"
        case .streakRepair: return "Streak repair & extra freezes"
        case .customChallenges: return "Build your own challenges"
        case .aiCoaching: return "AI habit coaching"
        }
    }

    var detail: String {
        switch self {
        case .unlimitedHabits: return "Track your whole routine, not just three of it."
        case .unlimitedAIVerification: return "Prove any habit, as often as you want."
        case .premiumShareTemplates: return "All 10 designs, Story and post formats."
        case .advancedInsights: return "See which habits actually move your score."
        case .streakRepair: return "Fix a missed day. One bad day shouldn't cost 30 good ones."
        case .customChallenges: return "Design and save your own 90-day programs."
        case .aiCoaching: return "Personalized nudges based on how your week is going."
        }
    }

    var symbol: String {
        switch self {
        case .unlimitedHabits: return "infinity"
        case .unlimitedAIVerification: return "camera.viewfinder"
        case .premiumShareTemplates: return "square.on.square"
        case .advancedInsights: return "chart.line.uptrend.xyaxis"
        case .streakRepair: return "flame.fill"
        case .customChallenges: return "wand.and.stars"
        case .aiCoaching: return "sparkles"
        }
    }

    /// Order shown on the paywall.
    static let paywallOrder: [PremiumFeature] = [
        .unlimitedHabits, .unlimitedAIVerification, .streakRepair,
        .premiumShareTemplates, .advancedInsights, .aiCoaching,
    ]
}
