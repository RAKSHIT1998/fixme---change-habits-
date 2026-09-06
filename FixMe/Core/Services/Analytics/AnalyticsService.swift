import Foundation

/// Vendor-agnostic analytics contract. Swap `ConsoleAnalyticsService` for a real backend later.
protocol AnalyticsService {
    func track(_ event: AnalyticsEvent)
}

enum AnalyticsEvent {
    case onboardingStarted
    case onboardingCompleted
    case journeyStarted
    case habitCreated(name: String)
    case habitCompleted(name: String)
    case habitVerified(name: String, status: VerificationStatus)
    case verificationFailed(name: String)
    case dailyJourneyCompleted(dayNumber: Int)
    case shareCreated(template: String)
    case shareExported(format: String)
    case ninetyDayCompleted

    // Revenue funnel — the events that tell you whether the business works.
    case paywallViewed(trigger: String)
    case paywallDismissed(trigger: String)
    case checkoutStarted(productID: String)
    case subscriptionStarted(productID: String, isTrial: Bool)
    case featureGateHit(feature: String)

    // Retention loops.
    case streakSaved(daysProtected: Int)
    case streakLost(daysLost: Int)
    case comebackAfterMissedDay(dayNumber: Int)
    case referralShared

    // The reel loop. `reel_exported` is the one that matters — a rendered reel nobody
    // posts is a rendering cost, not a growth loop, and the render/export ratio is the
    // only way to tell the two apart.
    case reelPromptShown(dayNumber: Int)
    case reelStarted(dayNumber: Int)
    case reelRendered(seconds: Int, scenes: Int)
    case reelExported(destination: String)

    var name: String {
        switch self {
        case .onboardingStarted: return "onboarding_started"
        case .onboardingCompleted: return "onboarding_completed"
        case .journeyStarted: return "journey_started"
        case .habitCreated: return "habit_created"
        case .habitCompleted: return "habit_completed"
        case .habitVerified: return "habit_verified"
        case .verificationFailed: return "verification_failed"
        case .dailyJourneyCompleted: return "daily_journey_completed"
        case .shareCreated: return "share_created"
        case .shareExported: return "share_exported"
        case .ninetyDayCompleted: return "90_day_completed"
        case .paywallViewed: return "paywall_viewed"
        case .paywallDismissed: return "paywall_dismissed"
        case .checkoutStarted: return "checkout_started"
        case .subscriptionStarted: return "subscription_started"
        case .featureGateHit: return "feature_gate_hit"
        case .streakSaved: return "streak_saved"
        case .streakLost: return "streak_lost"
        case .comebackAfterMissedDay: return "comeback_after_missed_day"
        case .referralShared: return "referral_shared"
        case .reelPromptShown: return "reel_prompt_shown"
        case .reelStarted: return "reel_started"
        case .reelRendered: return "reel_rendered"
        case .reelExported: return "reel_exported"
        }
    }
}

/// Development-time analytics sink. Prints to the console; no data leaves the device.
struct ConsoleAnalyticsService: AnalyticsService {
    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        print("[analytics] \(event.name)")
        #endif
    }
}
