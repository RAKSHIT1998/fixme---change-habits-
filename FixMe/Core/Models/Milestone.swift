import Foundation

/// Static catalog of 90-day journey milestones — not persisted.
struct Milestone: Identifiable {
    let day: Int
    let title: String
    let emoji: String
    var id: Int { day }

    static let all: [Milestone] = [
        Milestone(day: 7, title: "First Week", emoji: "🌱"),
        Milestone(day: 14, title: "Two Weeks", emoji: "⚡️"),
        Milestone(day: 30, title: "One Month", emoji: "🔥"),
        Milestone(day: 45, title: "Halfway", emoji: "🏔️"),
        Milestone(day: 60, title: "Momentum", emoji: "🚀"),
        Milestone(day: 75, title: "Almost There", emoji: "✨"),
        Milestone(day: 90, title: "TRANSFORMED", emoji: "🏆"),
    ]

    static func milestone(for day: Int) -> Milestone? {
        all.first { $0.day == day }
    }
}
