import Foundation
import SwiftData

/// What a post is about — drives both its layout and the feed filters.
enum SocialPostKind: String, Codable, CaseIterable {
    case dayRecap
    case milestone
    case photo
    case note

    var label: String {
        switch self {
        case .dayRecap: return "Day recap"
        case .milestone: return "Milestone"
        case .photo: return "Photo"
        case .note: return "Note"
        }
    }

    var symbol: String {
        switch self {
        case .dayRecap: return "checkmark.circle.fill"
        case .milestone: return "trophy.fill"
        case .photo: return "photo.fill"
        case .note: return "text.quote"
        }
    }
}

/// A post on the user's progress wall.
///
/// Stored locally. Nothing here is uploaded anywhere — there is no server behind this
/// feature, and the UI says so rather than implying an audience that doesn't exist.
/// `privacyLevel` records the user's intent so a future backend can honour it from day
/// one instead of retrofitting consent onto posts made under different assumptions.
@Model
final class SocialPost {
    var id: UUID
    var authorName: String
    var caption: String
    var dayNumber: Int
    var completionPercent: Int
    var createdAt: Date
    var privacyLevel: PrivacyLevel
    var imageFileName: String?
    var heartCount: Int
    var fireCount: Int
    var clapCount: Int

    var kind: SocialPostKind = SocialPostKind.dayRecap
    /// Habits completed on the day this post captures.
    var habitNames: [String] = []
    var streak: Int = 0
    var milestoneTitle: String? = nil

    init(
        id: UUID = UUID(),
        authorName: String,
        caption: String,
        dayNumber: Int,
        completionPercent: Int,
        createdAt: Date = .now,
        privacyLevel: PrivacyLevel = .privateOnly,
        imageFileName: String? = nil,
        heartCount: Int = 0,
        fireCount: Int = 0,
        clapCount: Int = 0,
        kind: SocialPostKind = .dayRecap,
        habitNames: [String] = [],
        streak: Int = 0,
        milestoneTitle: String? = nil
    ) {
        self.id = id
        self.authorName = authorName
        self.caption = caption
        self.dayNumber = dayNumber
        self.completionPercent = completionPercent
        self.createdAt = createdAt
        self.privacyLevel = privacyLevel
        self.imageFileName = imageFileName
        self.heartCount = heartCount
        self.fireCount = fireCount
        self.clapCount = clapCount
        self.kind = kind
        self.habitNames = habitNames
        self.streak = streak
        self.milestoneTitle = milestoneTitle
    }

    var hasPhoto: Bool { imageFileName != nil }

    var totalReactions: Int { heartCount + fireCount + clapCount }
}
