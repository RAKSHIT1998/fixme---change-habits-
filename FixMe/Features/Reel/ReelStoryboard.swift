import Foundation

/// One card in a progress reel, and how long it holds on screen.
struct ReelScene: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Opening frame. Short-form video is scrolled past in about a second, so the
        /// transformation claim has to be legible before anything else happens.
        case hook(name: String, fromDay: Int, toDay: Int)
        case photo(fileName: String, dayNumber: Int)
        case stat(value: String, label: String, footnote: String?)
        /// The only frame that asks for anything. Held long enough to actually read.
        case endCard(headline: String, code: String)
    }

    var id = UUID()
    let kind: Kind
    let duration: Double
}

/// Everything a reel needs, flattened out of SwiftData so the storyboard stays pure and
/// testable. Built from a `Journey` by `ReelInput.init(journey:user:)`.
struct ReelInput: Equatable {
    struct Photo: Equatable {
        let fileName: String
        let dayNumber: Int
    }

    /// The single most shareable thing this app produces. Kept separate from the build
    /// stats because clean time out-hooks every other number by a distance.
    struct Quit: Equatable {
        let title: String
        let cleanDays: Int
        let moneySaved: Double
        let cravingsResisted: Int
    }

    var name: String = ""
    var currentDay: Int = 1
    var totalDays: Int = 90
    var photos: [Photo] = []
    var daysShownUp: Int = 0
    var longestStreak: Int = 0
    var habitsKept: Int = 0
    var quit: Quit?
    var referralCode: String = ""
}

/// Turns a journey into an ordered list of scenes.
///
/// The shape is deliberate, not decorative: hook first, the user's own photos as the
/// spine, stats cut in on a rhythm so the middle doesn't sag, and exactly one ask at the
/// end. A reel with no photos still works — most people won't have taken many, and a
/// feature that only fires for the diligent minority is not a growth loop.
enum ReelStoryboard {
    static let maxPhotos = 12
    private static let maxStats = 3
    private static let photosPerStatBreak = 3

    enum Duration {
        static let hook = 1.6
        static let photo = 1.2
        static let stat = 1.7
        static let endCard = 2.8
    }

    static func scenes(for input: ReelInput) -> [ReelScene] {
        let photos = sample(input.photos, limit: maxPhotos)
        var stats = statScenes(for: input)
        var scenes: [ReelScene] = [
            ReelScene(
                kind: .hook(name: input.name, fromDay: 1, toDay: input.currentDay),
                duration: Duration.hook
            )
        ]

        for (index, photo) in photos.enumerated() {
            scenes.append(ReelScene(
                kind: .photo(fileName: photo.fileName, dayNumber: photo.dayNumber),
                duration: Duration.photo
            ))
            let isBreak = (index + 1) % photosPerStatBreak == 0
            if isBreak, index + 1 < photos.count, !stats.isEmpty {
                scenes.append(stats.removeFirst())
            }
        }

        // Anything the rhythm didn't consume still gets shown — on a photo-less reel this
        // is the entire middle.
        scenes.append(contentsOf: stats)
        scenes.append(ReelScene(
            kind: .endCard(headline: headline(for: input), code: input.referralCode),
            duration: Duration.endCard
        ))
        return scenes
    }

    static func totalDuration(of scenes: [ReelScene]) -> Double {
        scenes.reduce(0) { $0 + $1.duration }
    }

    /// Evenly spaced, always keeping the first and last photo — the two frames the whole
    /// before/after read depends on.
    static func sample(_ photos: [ReelInput.Photo], limit: Int) -> [ReelInput.Photo] {
        let sorted = photos.sorted { $0.dayNumber < $1.dayNumber }
        guard limit > 0 else { return [] }
        guard sorted.count > limit else { return sorted }
        guard limit > 1 else { return Array(sorted.prefix(1)) }

        let step = Double(sorted.count - 1) / Double(limit - 1)
        var picked: [ReelInput.Photo] = []
        for index in 0..<limit {
            let position = Int((Double(index) * step).rounded())
            let photo = sorted[min(position, sorted.count - 1)]
            if picked.last != photo { picked.append(photo) }
        }
        return picked
    }

    // MARK: - Stats

    /// Ordered by how well each number stops a scroll, not by how proud we are of it.
    private static func statScenes(for input: ReelInput) -> [ReelScene] {
        var candidates: [(value: String, label: String, footnote: String?)] = []

        if let quit = input.quit {
            if quit.cleanDays > 0 {
                candidates.append((
                    "\(quit.cleanDays)",
                    quit.cleanDays == 1 ? "DAY CLEAN" : "DAYS CLEAN",
                    quit.title.uppercased()
                ))
            }
            if quit.moneySaved >= 1 {
                candidates.append((money(quit.moneySaved), "SAVED", "NOT SPENT ON \(quit.title.uppercased())"))
            }
            if quit.cravingsResisted > 0 {
                candidates.append(("\(quit.cravingsResisted)", "CRAVINGS BEATEN", "EVERY ONE LOGGED"))
            }
        }
        if input.longestStreak > 1 {
            candidates.append(("\(input.longestStreak)", "DAY STREAK", "LONGEST RUN SO FAR"))
        }
        if input.daysShownUp > 0 {
            candidates.append((
                "\(input.daysShownUp)/\(input.currentDay)",
                "DAYS SHOWN UP",
                nil
            ))
        }
        if input.habitsKept > 0 {
            candidates.append((
                "\(input.habitsKept)",
                input.habitsKept == 1 ? "HABIT KEPT" : "HABITS KEPT",
                nil
            ))
        }

        let limit = input.photos.isEmpty ? maxStats + 1 : maxStats
        return candidates.prefix(limit).map {
            ReelScene(
                kind: .stat(value: $0.value, label: $0.label, footnote: $0.footnote),
                duration: Duration.stat
            )
        }
    }

    private static func headline(for input: ReelInput) -> String {
        if let quit = input.quit, quit.cleanDays > 0 {
            return "\(quit.cleanDays) days clean."
        }
        if input.longestStreak > 1 {
            return "\(input.longestStreak) days in a row."
        }
        return "Day \(input.currentDay) of \(input.totalDays)."
    }

    private static func money(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }
}
