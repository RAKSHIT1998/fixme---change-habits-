import Foundation

/// Decides when to offer a reel unprompted.
///
/// The reel lives behind an icon in the Journey tab, which means it only ever reaches
/// people who already thought to go looking. Distribution beats features: offering it at
/// the moment someone actually feels like posting is worth more than anything else that
/// could be added to the reel itself.
///
/// Milestone days are that moment — the day the number is worth saying out loud. Once per
/// milestone, never twice, and never while something more urgent is on screen: a broken
/// streak outranks a celebration, and the card that says so is the one that should show.
enum ReelPrompt {
    /// The milestone to celebrate today, or nil if there isn't one or it's already been
    /// offered. `lastPromptedDay` is the day number this prompt was last shown for.
    static func milestone(day: Int, lastPromptedDay: Int) -> Milestone? {
        guard day != lastPromptedDay else { return nil }
        return Milestone.milestone(for: day)
    }

    /// Copy for the card. Day 90 is the one that earns a different line — it's the whole
    /// promise of the app, and a generic "nice milestone" would undersell it.
    static func headline(for milestone: Milestone, totalDays: Int) -> String {
        milestone.day >= totalDays
            ? "You finished. Show them."
            : "\(milestone.day) days. Worth posting."
    }

    static func detail(for milestone: Milestone) -> String {
        milestone.day >= 30
            ? "Turn your photos and numbers into a video in about a minute."
            : "Make a video out of your first \(milestone.day) days."
    }
}
