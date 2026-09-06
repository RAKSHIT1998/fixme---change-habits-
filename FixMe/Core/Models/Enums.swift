import Foundation

/// How a habit's completion is confirmed.
enum VerificationType: String, Codable, CaseIterable, Identifiable {
    case healthKit
    case photoAI
    case manual
    case timer
    case location
    case hybrid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .healthKit: return "Apple Health"
        case .photoAI: return "AI Photo"
        case .manual: return "Self-reported"
        case .timer: return "Timer"
        case .location: return "Location"
        case .hybrid: return "Health + Photo"
        }
    }

    var badgeText: String {
        switch self {
        case .healthKit: return "Auto-verified"
        case .photoAI: return "AI verified"
        case .manual: return "Self-reported"
        case .timer: return "Timed"
        case .location: return "Location"
        case .hybrid: return "Verified"
        }
    }

    var symbol: String {
        switch self {
        case .healthKit: return "heart.fill"
        case .photoAI: return "camera.viewfinder"
        case .manual: return "hand.tap.fill"
        case .timer: return "timer"
        case .location: return "location.fill"
        case .hybrid: return "checkmark.seal.fill"
        }
    }
}

enum HabitCategory: String, Codable, CaseIterable, Identifiable {
    case energy, fitness, mind, learning, sleep, nutrition, calm, health, digital, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .energy: return "Energy"
        case .fitness: return "Fitness"
        case .mind: return "Mind"
        case .learning: return "Learning"
        case .sleep: return "Sleep"
        case .nutrition: return "Nutrition"
        case .calm: return "Calm"
        case .health: return "Health"
        case .digital: return "Digital Life"
        case .custom: return "Custom"
        }
    }

    var emoji: String {
        switch self {
        case .energy: return "🔥"
        case .fitness: return "💪"
        case .mind: return "🧠"
        case .learning: return "📚"
        case .sleep: return "😴"
        case .nutrition: return "🥗"
        case .calm: return "🧘"
        case .health: return "💧"
        case .digital: return "📵"
        case .custom: return "✨"
        }
    }
}

/// Lifecycle state of a single habit on a single day.
enum HabitDayState: String, Codable {
    case notStarted
    case inProgress
    case waitingForProof
    case verified
    case completed
    case missed

    var label: String {
        switch self {
        case .notStarted: return "Not started"
        case .inProgress: return "In progress"
        case .waitingForProof: return "Checking..."
        case .verified: return "Verified"
        case .completed: return "Done"
        case .missed: return "Missed"
        }
    }

    var isDone: Bool { self == .verified || self == .completed }
}

enum CommitmentLevel: String, Codable, CaseIterable, Identifiable {
    case casual, committed, lockedIn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .casual: return "Casual"
        case .committed: return "Committed"
        case .lockedIn: return "LOCKED IN"
        }
    }

    var sliderValue: Double {
        switch self {
        case .casual: return 0
        case .committed: return 0.5
        case .lockedIn: return 1
        }
    }

    static func from(sliderValue: Double) -> CommitmentLevel {
        switch sliderValue {
        case ..<0.33: return .casual
        case 0.33..<0.75: return .committed
        default: return .lockedIn
        }
    }
}

enum VerificationStatus: String, Codable {
    case verified
    case needsReview = "needs_review"
    case rejected
    case unableToVerify = "unable_to_verify"
}

enum TransformationLevel: String, Codable, CaseIterable {
    case gettingStarted, building, consistent, lockedIn, transformed

    var title: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .building: return "Building"
        case .consistent: return "Consistent"
        case .lockedIn: return "Locked In"
        case .transformed: return "Transformed"
        }
    }

    static func forXP(_ xp: Int) -> TransformationLevel {
        switch xp {
        case ..<200: return .gettingStarted
        case 200..<800: return .building
        case 800..<2000: return .consistent
        case 2000..<5000: return .lockedIn
        default: return .transformed
        }
    }
}

enum PrivacyLevel: String, Codable, CaseIterable, Identifiable {
    case privateOnly, friends, publicShare
    var id: String { rawValue }
    var title: String {
        switch self {
        case .privateOnly: return "Private"
        case .friends: return "Friends"
        case .publicShare: return "Public"
        }
    }
}
