import Foundation
import SwiftData

@Model
final class Badge {
    var id: UUID
    var badgeIdentifier: String   // matches BadgeDefinition.id
    var unlockedAt: Date
    var owner: User?

    init(id: UUID = UUID(), badgeIdentifier: String, unlockedAt: Date = .now) {
        self.id = id
        self.badgeIdentifier = badgeIdentifier
        self.unlockedAt = unlockedAt
    }
}

/// Static catalog of achievable badges. Not persisted — matched against `Badge.badgeIdentifier`.
struct BadgeDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
    let requirement: String

    static let all: [BadgeDefinition] = [
        BadgeDefinition(id: "early_bird", title: "Early Bird", emoji: "🌅", requirement: "7 early wake-ups"),
        BadgeDefinition(id: "bookworm", title: "Bookworm", emoji: "📚", requirement: "100 pages read"),
        BadgeDefinition(id: "hydrated", title: "Hydrated", emoji: "💧", requirement: "7-day water goal"),
        BadgeDefinition(id: "walker", title: "Walker", emoji: "👟", requirement: "100K steps"),
        BadgeDefinition(id: "on_fire", title: "On Fire", emoji: "🔥", requirement: "14-day streak"),
        BadgeDefinition(id: "calm_mind", title: "Calm Mind", emoji: "🧘", requirement: "10 meditation sessions"),
        BadgeDefinition(id: "ninety_days", title: "90 Days", emoji: "🏆", requirement: "Completed a transformation"),
    ]
}
