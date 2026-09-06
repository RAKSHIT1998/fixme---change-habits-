import Foundation

/// Central place for XP math so reward numbers stay consistent across the app.
enum XPService {
    static let habitCompletionXP = 20
    static let verificationBonusXP = 10
    static let fullDayBonusXP = 50
    static let sevenDayMilestoneXP = 100

    static func awardForCompletion(verified: Bool) -> Int {
        verified ? habitCompletionXP + verificationBonusXP : habitCompletionXP
    }
}
