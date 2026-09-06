import Foundation
import SwiftData

@Model
final class User {
    var id: UUID
    var name: String
    var avatarSystemImage: String
    var createdAt: Date
    var totalXP: Int
    var privacyLevel: PrivacyLevel

    /// Streak protection bookkeeping. Freezes reset monthly; the allowance itself comes
    /// from `PremiumGate` so packaging can change without a migration.
    var streakFreezesUsedThisMonth: Int = 0
    var lastFreezeResetMonth: Date? = nil

    /// Stable code used for the invite loop.
    var referralCode: String = String(UUID().uuidString.prefix(6)).uppercased()
    var referralsConverted: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \Journey.owner)
    var journeys: [Journey] = []

    @Relationship(deleteRule: .cascade, inverse: \Badge.owner)
    var badges: [Badge] = []

    var settings: UserSettings?

    init(
        id: UUID = UUID(),
        name: String = "You",
        avatarSystemImage: String = "person.crop.circle.fill",
        createdAt: Date = .now,
        totalXP: Int = 0,
        privacyLevel: PrivacyLevel = .privateOnly
    ) {
        self.id = id
        self.name = name
        self.avatarSystemImage = avatarSystemImage
        self.createdAt = createdAt
        self.totalXP = totalXP
        self.privacyLevel = privacyLevel
    }

    var transformationLevel: TransformationLevel { .forXP(totalXP) }
}
