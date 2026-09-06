import Foundation
import SwiftData
import UIKit

/// What the user is composing, before it becomes a stored post.
struct SocialPostDraft {
    var kind: SocialPostKind = .dayRecap
    var caption: String = ""
    var dayNumber: Int = 0
    var completionPercent: Int = 0
    var streak: Int = 0
    var habitNames: [String] = []
    var milestoneTitle: String?
    var image: UIImage?
    var privacyLevel: PrivacyLevel = .privateOnly
}

/// How the feed is being filtered. Every case here is backed by real data — there are no
/// decorative controls.
enum FeedFilter: String, CaseIterable, Identifiable {
    case all, milestones, photos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .milestones: return "Milestones"
        case .photos: return "Photos"
        }
    }

    func matches(_ post: SocialPost) -> Bool {
        switch self {
        case .all: return true
        case .milestones: return post.kind == .milestone
        case .photos: return post.hasPhoto
        }
    }
}

/// The social layer's contract.
///
/// Deliberately shaped so a networked implementation (CloudKit's public database being
/// the obvious candidate — Apple-hosted, no server to run) can replace the local one
/// without touching a single call site.
@MainActor
protocol SocialService {
    /// False when there is no backend, so no other people can exist in the feed.
    /// The UI reads this rather than hardcoding copy, so it stops claiming "your wall"
    /// the moment a real implementation is plugged in.
    var supportsOtherPeople: Bool { get }

    func publish(_ draft: SocialPostDraft, authorName: String) throws -> SocialPost
    func posts(matching filter: FeedFilter) throws -> [SocialPost]
    func react(_ reaction: SocialReaction, to post: SocialPost)
    func delete(_ post: SocialPost)
}

enum SocialReaction: String, CaseIterable, Identifiable {
    case heart, fire, clap

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .heart: return "❤️"
        case .fire: return "🔥"
        case .clap: return "👏"
        }
    }
}

/// The implementation that ships today: everything is stored on-device with SwiftData.
///
/// This is a complete, working feature rather than a stub — posting, filtering, reacting
/// and deleting all function end to end. What it cannot do is show you other people,
/// because that needs a server.
@MainActor
struct LocalSocialService: SocialService {
    let modelContext: ModelContext

    var supportsOtherPeople: Bool { false }

    func publish(_ draft: SocialPostDraft, authorName: String) throws -> SocialPost {
        // Photos are copied into the app's own store so a post can't break later when the
        // source image is deleted from the library.
        let fileName = draft.image.flatMap { ImageStore.save($0) }

        let post = SocialPost(
            authorName: authorName,
            caption: draft.caption.trimmingCharacters(in: .whitespacesAndNewlines),
            dayNumber: draft.dayNumber,
            completionPercent: draft.completionPercent,
            privacyLevel: draft.privacyLevel,
            imageFileName: fileName,
            kind: draft.kind,
            habitNames: draft.habitNames,
            streak: draft.streak,
            milestoneTitle: draft.milestoneTitle
        )
        modelContext.insert(post)
        try modelContext.save()
        return post
    }

    func posts(matching filter: FeedFilter) throws -> [SocialPost] {
        let descriptor = FetchDescriptor<SocialPost>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).filter(filter.matches)
    }

    func react(_ reaction: SocialReaction, to post: SocialPost) {
        switch reaction {
        case .heart: post.heartCount += 1
        case .fire: post.fireCount += 1
        case .clap: post.clapCount += 1
        }
        try? modelContext.save()
    }

    func delete(_ post: SocialPost) {
        // Take the attached photo with it — leaving orphaned images on disk after the
        // user deletes a post is a quiet privacy failure.
        if let fileName = post.imageFileName {
            ImageStore.deleteImage(fileName)
        }
        modelContext.delete(post)
        try? modelContext.save()
    }
}
