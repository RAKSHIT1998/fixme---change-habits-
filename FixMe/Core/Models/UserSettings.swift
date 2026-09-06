import Foundation
import SwiftData

@Model
final class UserSettings {
    var soundEnabled: Bool
    var hapticsEnabled: Bool
    var reduceMotionOverride: Bool
    var healthKitAuthorized: Bool
    var notificationsAuthorized: Bool
    var owner: User?

    init(
        soundEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        reduceMotionOverride: Bool = false,
        healthKitAuthorized: Bool = false,
        notificationsAuthorized: Bool = false
    ) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.reduceMotionOverride = reduceMotionOverride
        self.healthKitAuthorized = healthKitAuthorized
        self.notificationsAuthorized = notificationsAuthorized
    }
}
