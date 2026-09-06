import Testing
import Foundation
import SwiftData
import UIKit
@testable import FixMe

/// These back user-facing privacy promises, so they're tested rather than assumed.
/// Both controls previously did nothing at all.
@MainActor
struct DataPrivacyTests {
    let container: ModelContainer
    let service: DataPrivacyService

    init() throws {
        container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        service = DataPrivacyService(modelContext: container.mainContext)
    }

    private func seed() {
        let context = container.mainContext
        let user = User(name: "Alex", totalXP: 120)
        context.insert(user)

        let journey = Journey(title: "My 90 Days")
        journey.owner = user
        context.insert(journey)

        let habit = HabitCatalog.all[3].makeHabit()
        habit.journey = journey
        let completion = HabitCompletion(date: .now, state: .completed, progressValue: 20, xpAwarded: 20)
        completion.habit = habit
        habit.completions.append(completion)
        context.insert(habit)
        context.insert(completion)
        try? context.save()
    }

    @Test func exportProducesReadableJSONContainingTheUsersData() throws {
        seed()
        let data = try service.exportJSON()
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["exportedAt"] != nil)
        let profile = try #require(object["profile"] as? [String: Any])
        #expect(profile["name"] as? String == "Alex")

        let journeys = try #require(object["journeys"] as? [[String: Any]])
        #expect(journeys.count == 1)
        let habits = try #require(journeys[0]["habits"] as? [[String: Any]])
        #expect(habits.count == 1)
        #expect((habits[0]["completions"] as? [[String: Any]])?.count == 1)
    }

    /// The peer signing key is the one secret that proves you are you to friends. An
    /// export is usually shared through a messaging app, so it must never travel with it.
    @Test func exportNeverContainsKeyMaterial() throws {
        seed()
        let json = String(decoding: try service.exportJSON(), as: UTF8.self).lowercased()
        for forbidden in ["privatekey", "rawrepresentation", "signature", "secret"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func exportWritesAFileTheShareSheetCanUse() throws {
        seed()
        let url = try service.exportToTemporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.pathExtension == "json")
        #expect((try Data(contentsOf: url)).count > 0)
    }

    @Test func deletingPhotosRemovesFilesAndClearsReferences() throws {
        let context = container.mainContext
        let image = try #require(UIImage(systemName: "star"))
        let fileName = try #require(ImageStore.save(image))

        let result = VerificationResult(
            status: .verified, confidence: 0.9, evidenceSummary: "ok",
            explanation: "ok", imageFileName: fileName, source: .photoAI
        )
        context.insert(result)
        let post = SocialPost(
            authorName: "Alex", caption: "hi", dayNumber: 1,
            completionPercent: 50, imageFileName: fileName
        )
        context.insert(post)
        try context.save()

        #expect(ImageStore.load(fileName) != nil)

        let removed = service.deleteAllPhotos()

        #expect(removed >= 1)
        #expect(ImageStore.load(fileName) == nil)
        // References must be cleared too, or the UI shows a broken image.
        #expect(result.imageFileName == nil)
        #expect(post.imageFileName == nil)
    }

    @Test func deletingPhotosKeepsHabitsAndHistory() throws {
        seed()
        _ = service.deleteAllPhotos()

        let habits = (try? container.mainContext.fetch(FetchDescriptor<Habit>())) ?? []
        #expect(habits.count == 1)
        #expect(habits.first?.completions.count == 1)
    }
}

@MainActor
struct GuideContentTests {
    /// The guide is the app's only explanation of its non-obvious rules, so it shouldn't
    /// silently lose a section or ship an empty one.
    @Test func everySectionIsNumberedAndPopulated() {
        let sections = GuideSection.all
        #expect(sections.count >= 8)
        #expect(Set(sections.map(\.id)).count == sections.count)
        #expect(sections.map(\.number) == Array(1...sections.count))
        for section in sections {
            #expect(!section.title.isEmpty)
            #expect(!section.steps.isEmpty)
            #expect(section.steps.allSatisfy { !$0.text.isEmpty })
        }
    }

    /// The two easiest things to misunderstand — and the two most likely to make someone
    /// quit the app if they get them wrong.
    @Test func guideExplainsTheRulesThatAreNotSelfEvident() {
        let text = GuideSection.all
            .flatMap { $0.steps.map { "\($0.text) \($0.detail ?? "")" } }
            .joined(separator: " ")
            .lowercased()

        #expect(text.contains("count as kept"))     // quit habits need no daily tap
        #expect(text.contains("streak freeze"))     // a missed day is recoverable
        #expect(text.contains("silent mode"))       // alarms can't override it
        #expect(text.contains("no server"))         // friends are peer-to-peer
    }
}

/// Regression cover for the widget showing Day 17 on a Day 1 journey.
///
/// Two things went wrong together: the snapshot was only written when a habit was
/// completed, and the widget substituted sample data when none existed. Either alone
/// would have been visible; together they produced convincing fake progress.
@MainActor
struct WidgetSnapshotTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    private func makeJourney(startedDaysAgo: Int, habitCount: Int = 2) -> Journey {
        let context = container.mainContext
        let journey = Journey(
            startDate: Calendar.current.date(byAdding: .day, value: -startedDaysAgo, to: .now.startOfDay) ?? .now
        )
        context.insert(journey)
        for index in 0..<habitCount {
            let habit = HabitCatalog.all[index].makeHabit(sortOrder: index)
            habit.journey = journey
            context.insert(habit)
        }
        try? context.save()
        return journey
    }

    @Test func aBrandNewJourneyReportsDayOne() {
        let journey = makeJourney(startedDaysAgo: 0)
        let snapshot = WidgetSnapshotPublisher.snapshot(for: journey)

        #expect(snapshot.dayNumber == 1)
        #expect(snapshot.completionPercent == 0)
        #expect(snapshot.currentStreak == 0)
        // The exact symptom that was reported.
        #expect(snapshot.dayNumber != WidgetSnapshot.galleryPreview.dayNumber)
    }

    @Test func snapshotTracksTheJourneysActualDay() {
        #expect(WidgetSnapshotPublisher.snapshot(for: makeJourney(startedDaysAgo: 16)).dayNumber == 17)
        #expect(WidgetSnapshotPublisher.snapshot(for: makeJourney(startedDaysAgo: 3)).dayNumber == 4)
    }

    @Test func completionPercentReflectsFinishedHabits() throws {
        let journey = makeJourney(startedDaysAgo: 2, habitCount: 2)
        let habit = try #require(journey.habits.first)

        let completion = HabitCompletion(date: .now, state: .completed)
        completion.habit = habit
        habit.completions.append(completion)
        try container.mainContext.save()

        #expect(WidgetSnapshotPublisher.snapshot(for: journey).completionPercent == 50)
    }

    @Test func nextHabitSkipsCompletedAndQuitHabits() throws {
        let journey = makeJourney(startedDaysAgo: 1, habitCount: 2)
        let first = try #require(journey.habits.sorted { $0.sortOrder < $1.sortOrder }.first)

        let done = HabitCompletion(date: .now, state: .completed)
        done.habit = first
        first.completions.append(done)
        try container.mainContext.save()

        let snapshot = WidgetSnapshotPublisher.snapshot(for: journey)
        #expect(snapshot.nextHabitName != nil)
        #expect(snapshot.nextHabitName != first.name)
    }

    /// With no journey the widget must show its empty state, not a stale or invented one.
    @Test func publishingWithNoActiveJourneyClearsTheWidget() {
        let journey = makeJourney(startedDaysAgo: 5)
        WidgetSnapshotPublisher.publish(journey: journey)

        journey.isActive = false
        try? container.mainContext.save()
        WidgetSnapshotPublisher.publish(from: container.mainContext)

        #expect(WidgetSnapshotStore.load() == nil)
    }
}

/// Apple rejects subscription paywalls without working Terms and Privacy links
/// (Guideline 3.1.2). These were empty closures; this guards the content behind them.
@MainActor
struct LegalDocumentTests {

    @Test func bothDocumentsExistAndArePopulated() {
        for document in LegalDocument.allCases {
            #expect(!document.title.isEmpty)
            #expect(document.sections.count >= 5)
            for section in document.sections {
                #expect(!section.heading.isEmpty)
                #expect(section.body.count > 40)
            }
        }
    }

    /// Apple specifically requires auto-renewing subscription terms to state renewal and
    /// cancellation behaviour.
    @Test func termsCoverSubscriptionRenewalRules() {
        let text = LegalDocument.terms.sections
            .map { "\($0.heading) \($0.body)" }.joined(separator: " ").lowercased()

        #expect(text.contains("auto-renew"))
        #expect(text.contains("cancel"))
        #expect(text.contains("24 hours"))
    }

    /// The safety and honesty claims the rest of the app depends on.
    @Test func termsDisclaimMedicalAdviceAndAlarmReliability() {
        let text = LegalDocument.terms.sections
            .map(\.body).joined(separator: " ").lowercased()

        #expect(text.contains("medical advice"))
        #expect(text.contains("doctor"))
        #expect(text.contains("alarm"))
        #expect(text.contains("does not prove"))
    }

    /// The privacy policy must describe every sensitive permission the app requests.
    @Test func privacyPolicyCoversEverySensitivePermission() {
        let text = LegalDocument.privacy.sections
            .map { "\($0.heading) \($0.body)" }.joined(separator: " ").lowercased()

        for topic in ["health", "photo", "contact", "friend", "subscription"] {
            #expect(text.contains(topic), "privacy policy should mention \(topic)")
        }
        #expect(text.contains("no servers") || text.contains("never reach us"))
    }
}
