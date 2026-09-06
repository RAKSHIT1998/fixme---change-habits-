import Foundation
import SwiftData

/// A logged relapse.
///
/// Kept as history rather than being used to wipe the slate: the clean-run counter
/// resets, but total clean days, longest run and attempt count all survive. People who
/// quit successfully almost always relapse several times first, and an app that erases
/// their progress when it happens is an app they delete.
@Model
final class RelapseEvent {
    var id: UUID
    var date: Date
    /// Length of the clean run that just ended, in seconds — recorded so history survives the reset.
    var runDuration: TimeInterval
    /// Optional, freeform: what led to it. Useful for spotting patterns, never required.
    var trigger: String?
    var habit: Habit?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        runDuration: TimeInterval = 0,
        trigger: String? = nil
    ) {
        self.id = id
        self.date = date
        self.runDuration = runDuration
        self.trigger = trigger
    }
}

/// A craving the user rode out instead of acting on.
///
/// Logging these turns the invisible work of *not* doing something into visible progress,
/// which is most of what makes a quit tracker feel worth opening.
@Model
final class CravingEvent {
    var id: UUID
    var date: Date
    var intensity: Int          // 1...5 as reported by the user
    var didResist: Bool
    var durationSeconds: Int
    var habit: Habit?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        intensity: Int = 3,
        didResist: Bool = true,
        durationSeconds: Int = 0
    ) {
        self.id = id
        self.date = date
        self.intensity = intensity
        self.didResist = didResist
        self.durationSeconds = durationSeconds
    }
}
