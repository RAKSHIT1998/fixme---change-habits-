import Foundation

/// Streak math, kept separate from the model layer so the "don't punish one miss" rule
/// lives in exactly one place. A missed day breaks the *counted* streak but never blocks
/// the journey — recovery is just "today still counts."
enum StreakService {
    /// Given the array of day-level completion booleans (oldest → newest, missing days = false),
    /// returns (current, best).
    static func computeStreaks(dayCompletions: [Bool]) -> (current: Int, best: Int) {
        var current = 0
        var best = 0
        var running = 0
        for done in dayCompletions {
            if done {
                running += 1
                best = max(best, running)
            } else {
                running = 0
            }
        }
        // Current streak = trailing run at the end of the array.
        for done in dayCompletions.reversed() {
            if done { current += 1 } else { break }
        }
        return (current, best)
    }
}
