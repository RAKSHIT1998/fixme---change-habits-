import Testing
import Foundation
import SwiftData
import UIKit
@testable import FixMe

@MainActor
struct SocialServiceTests {

    /// `ModelContext` does not retain its `ModelContainer`. Holding the container as a
    /// stored property keeps it alive for the whole test — returning only a context from
    /// a helper leaves it dangling the moment the container deallocates, which traps
    /// inside SwiftData rather than failing cleanly.
    let container: ModelContainer
    let service: LocalSocialService

    init() throws {
        container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        service = LocalSocialService(modelContext: container.mainContext)
    }

    /// Regression for the original defect: nothing in the app could create a post, so the
    /// feed was permanently empty and the empty state was the only reachable state.
    @Test func publishingActuallyCreatesAReadablePost() throws {

        #expect(try service.posts(matching: .all).isEmpty)

        let draft = SocialPostDraft(
            kind: .dayRecap, caption: "Day one down.",
            dayNumber: 1, completionPercent: 80, streak: 1,
            habitNames: ["Read", "10K Steps"]
        )
        let created = try service.publish(draft, authorName: "Alex")

        let feed = try service.posts(matching: .all)
        #expect(feed.count == 1)
        #expect(feed.first?.id == created.id)
        #expect(feed.first?.caption == "Day one down.")
        #expect(feed.first?.habitNames == ["Read", "10K Steps"])
        #expect(feed.first?.authorName == "Alex")
    }

    /// Regression: the old segmented control was decorative — it filtered nothing.
    @Test func filtersActuallyFilter() throws {

        _ = try service.publish(SocialPostDraft(kind: .dayRecap, dayNumber: 1), authorName: "Alex")
        _ = try service.publish(
            SocialPostDraft(kind: .milestone, dayNumber: 7, milestoneTitle: "First Week"),
            authorName: "Alex"
        )
        _ = try service.publish(
            SocialPostDraft(kind: .photo, dayNumber: 8, image: UIImage(systemName: "star")),
            authorName: "Alex"
        )

        #expect(try service.posts(matching: .all).count == 3)
        #expect(try service.posts(matching: .milestones).count == 1)
        #expect(try service.posts(matching: .milestones).first?.milestoneTitle == "First Week")
        #expect(try service.posts(matching: .photos).count == 1)
        #expect(try service.posts(matching: .photos).first?.hasPhoto == true)
    }

    @Test func feedIsNewestFirst() throws {
        let context = container.mainContext

        let older = try service.publish(SocialPostDraft(dayNumber: 1), authorName: "Alex")
        older.createdAt = Date.now.addingTimeInterval(-86_400)
        let newer = try service.publish(SocialPostDraft(dayNumber: 2), authorName: "Alex")
        try context.save()

        #expect(try service.posts(matching: .all).first?.id == newer.id)
    }

    @Test func reactionsPersist() throws {
        let post = try service.publish(SocialPostDraft(dayNumber: 1), authorName: "Alex")

        service.react(.heart, to: post)
        service.react(.heart, to: post)
        service.react(.fire, to: post)

        let stored = try #require(try service.posts(matching: .all).first)
        #expect(stored.heartCount == 2)
        #expect(stored.fireCount == 1)
        #expect(stored.clapCount == 0)
        #expect(stored.totalReactions == 3)
    }

    @Test func deletingRemovesThePostAndItsPhoto() throws {
        let post = try service.publish(
            SocialPostDraft(dayNumber: 1, image: UIImage(systemName: "star")),
            authorName: "Alex"
        )
        let fileName = try #require(post.imageFileName)
        #expect(ImageStore.load(fileName) != nil)

        service.delete(post)

        #expect(try service.posts(matching: .all).isEmpty)
        // An orphaned image left on disk after a delete is a quiet privacy failure.
        #expect(ImageStore.load(fileName) == nil)
    }

    @Test func postsDefaultToPrivate() throws {
        let post = try service.publish(SocialPostDraft(dayNumber: 1), authorName: "Alex")
        #expect(post.privacyLevel == .privateOnly)
    }

    /// The local implementation must never claim it can show other people — the UI keys
    /// its copy off this, so a wrong answer here means the app lies to the user.
    @Test func localServiceDoesNotClaimToSupportOtherPeople() throws {
        #expect(service.supportsOtherPeople == false)
    }
}
