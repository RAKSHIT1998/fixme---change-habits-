import Foundation
import SwiftData

/// Backs the "Your data" controls in Settings.
///
/// These existed as buttons that did nothing, which is worse than not offering them —
/// a privacy control that silently no-ops is a promise the app doesn't keep.
@MainActor
struct DataPrivacyService {
    let modelContext: ModelContext

    // MARK: - Export

    /// Everything the app knows about you, as readable JSON.
    ///
    /// Deliberately excludes the peer signing key: it lives in the Keychain, it's the one
    /// secret that proves you are you to friends, and putting it in a file the user is
    /// about to share through a messaging app would be reckless.
    func exportJSON() throws -> Data {
        let users = (try? modelContext.fetch(FetchDescriptor<User>())) ?? []
        let journeys = (try? modelContext.fetch(FetchDescriptor<Journey>())) ?? []
        let friends = (try? modelContext.fetch(FetchDescriptor<Friend>())) ?? []
        let posts = (try? modelContext.fetch(FetchDescriptor<SocialPost>())) ?? []

        let export = Export(
            exportedAt: .now,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            profile: users.first.map {
                Export.Profile(name: $0.name, totalXP: $0.totalXP, privacyLevel: $0.privacyLevel.rawValue)
            },
            journeys: journeys.map { journey in
                Export.JourneyExport(
                    title: journey.title,
                    startDate: journey.startDate,
                    lengthInDays: journey.lengthInDays,
                    isActive: journey.isActive,
                    habits: journey.habits.sorted { $0.sortOrder < $1.sortOrder }.map { habit in
                        Export.HabitExport(
                            name: habit.name,
                            kind: habit.kind.rawValue,
                            goal: habit.goalDescription,
                            verification: habit.verificationType.rawValue,
                            quitStartDate: habit.quitStartDate,
                            completions: habit.completions
                                .sorted { $0.date < $1.date }
                                .map {
                                    Export.CompletionExport(
                                        date: $0.date, state: $0.state.rawValue,
                                        progress: $0.progressValue, xp: $0.xpAwarded
                                    )
                                },
                            relapses: habit.relapses.sorted { $0.date < $1.date }.map {
                                Export.RelapseExport(date: $0.date, runDuration: $0.runDuration, trigger: $0.trigger)
                            }
                        )
                    },
                    days: journey.dayProgresses.sorted { $0.date < $1.date }.map {
                        Export.DayExport(
                            date: $0.date, dayNumber: $0.dayNumber,
                            score: $0.dailyScore, journal: $0.journalEntry
                        )
                    }
                )
            },
            friends: friends.map {
                Export.FriendExport(displayName: $0.displayName, addedAt: $0.addedAt, updateCount: $0.updates.count)
            },
            posts: posts.map {
                Export.PostExport(caption: $0.caption, dayNumber: $0.dayNumber, createdAt: $0.createdAt)
            },
            photoCount: ImageStore.allFileNames().count
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    /// Writes the export to a temporary file for the share sheet.
    func exportToTemporaryFile() throws -> URL {
        let data = try exportJSON()
        let name = "FixMe-export-\(Int(Date.now.timeIntervalSince1970)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Photo deletion

    /// Deletes every stored photo and clears the references pointing at them, so nothing
    /// is left showing a broken image.
    @discardableResult
    func deleteAllPhotos() -> Int {
        for result in (try? modelContext.fetch(FetchDescriptor<VerificationResult>())) ?? [] {
            result.imageFileName = nil
        }
        for photo in (try? modelContext.fetch(FetchDescriptor<DailyPhoto>())) ?? [] {
            modelContext.delete(photo)
        }
        for post in (try? modelContext.fetch(FetchDescriptor<SocialPost>())) ?? [] {
            post.imageFileName = nil
        }
        let removed = ImageStore.deleteAll()
        try? modelContext.save()
        return removed
    }
}

// MARK: - Export shape

private struct Export: Encodable {
    let exportedAt: Date
    let appVersion: String
    let profile: Profile?
    let journeys: [JourneyExport]
    let friends: [FriendExport]
    let posts: [PostExport]
    let photoCount: Int

    struct Profile: Encodable {
        let name: String
        let totalXP: Int
        let privacyLevel: String
    }
    struct JourneyExport: Encodable {
        let title: String
        let startDate: Date
        let lengthInDays: Int
        let isActive: Bool
        let habits: [HabitExport]
        let days: [DayExport]
    }
    struct HabitExport: Encodable {
        let name: String
        let kind: String
        let goal: String
        let verification: String
        let quitStartDate: Date?
        let completions: [CompletionExport]
        let relapses: [RelapseExport]
    }
    struct CompletionExport: Encodable {
        let date: Date
        let state: String
        let progress: Double
        let xp: Int
    }
    struct RelapseExport: Encodable {
        let date: Date
        let runDuration: TimeInterval
        let trigger: String?
    }
    struct DayExport: Encodable {
        let date: Date
        let dayNumber: Int
        let score: Int
        let journal: String?
    }
    struct FriendExport: Encodable {
        let displayName: String
        let addedAt: Date
        let updateCount: Int
    }
    struct PostExport: Encodable {
        let caption: String
        let dayNumber: Int
        let createdAt: Date
    }
}
