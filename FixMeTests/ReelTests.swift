import Testing
import Foundation
import AVFoundation
import UIKit
@testable import FixMe

/// The reel is the app's outbound growth loop, so the rules that decide what goes in one
/// are worth pinning down: it has to survive users with no photos, users with far too
/// many, and it must always end on the frame that asks people to join.
struct ReelStoryboardTests {

    private func photos(_ days: [Int]) -> [ReelInput.Photo] {
        days.map { ReelInput.Photo(fileName: "day\($0).jpg", dayNumber: $0) }
    }

    private var baseInput: ReelInput {
        ReelInput(
            name: "Alex",
            currentDay: 47,
            totalDays: 90,
            photos: photos(Array(1...20)),
            daysShownUp: 41,
            longestStreak: 12,
            habitsKept: 4,
            quit: nil,
            referralCode: "AB12CD"
        )
    }

    @Test func opensOnTheHookAndClosesOnTheAsk() {
        let scenes = ReelStoryboard.scenes(for: baseInput)

        guard case let .hook(name, fromDay, toDay) = scenes.first?.kind else {
            Issue.record("reel must open on the hook frame")
            return
        }
        #expect(name == "Alex")
        #expect(fromDay == 1)
        #expect(toDay == 47)

        guard case let .endCard(_, code) = scenes.last?.kind else {
            Issue.record("reel must end on the card carrying the invite code")
            return
        }
        #expect(code == "AB12CD")
    }

    /// A 90-day journey can hold 90 photos. Showing them all would produce a two-minute
    /// video nobody watches to the end, which is where the invite lives.
    @Test func capsPhotoCountAndKeepsFirstAndLast() {
        let input = ReelInput(currentDay: 90, photos: photos(Array(1...90)), referralCode: "X")
        let scenes = ReelStoryboard.scenes(for: input)

        let photoDays: [Int] = scenes.compactMap {
            if case let .photo(_, day) = $0.kind { return day }
            return nil
        }
        #expect(photoDays.count <= ReelStoryboard.maxPhotos)
        #expect(photoDays.first == 1)
        #expect(photoDays.last == 90)
        #expect(photoDays == photoDays.sorted(), "photos must run in chronological order")
    }

    /// Most people won't have taken daily photos. A loop that only fires for the diligent
    /// minority isn't a loop.
    @Test func stillBuildsAReelWithNoPhotos() {
        let input = ReelInput(
            currentDay: 30,
            photos: [],
            daysShownUp: 27,
            longestStreak: 9,
            habitsKept: 3,
            referralCode: "NOPICS"
        )
        let scenes = ReelStoryboard.scenes(for: input)

        #expect(scenes.count >= 3, "a stat-only reel still needs a middle")
        let statCount = scenes.filter { if case .stat = $0.kind { return true }; return false }.count
        #expect(statCount >= 2)
        if case .endCard = scenes.last?.kind {} else {
            Issue.record("reel must still end on the invite card")
        }
    }

    /// Clean time out-hooks every other number this app produces, so it leads.
    @Test func quitStatsLeadWhenPresent() {
        var input = baseInput
        input.quit = ReelInput.Quit(
            title: "Smoking",
            cleanDays: 47,
            moneySaved: 235,
            cravingsResisted: 18
        )
        let scenes = ReelStoryboard.scenes(for: input)

        let firstStat = scenes.first { if case .stat = $0.kind { return true }; return false }
        guard case let .stat(value, label, _) = firstStat?.kind else {
            Issue.record("expected at least one stat frame")
            return
        }
        #expect(value == "47")
        #expect(label == "DAYS CLEAN")

        guard case let .endCard(headline, _) = scenes.last?.kind else { return }
        #expect(headline == "47 days clean.")
    }

    /// Short-form video gets scrolled past. Anything much over ~30s loses the end card.
    @Test func staysInShortFormLength() {
        let input = ReelInput(currentDay: 90, photos: photos(Array(1...90)), referralCode: "X")
        let duration = ReelStoryboard.totalDuration(of: ReelStoryboard.scenes(for: input))
        #expect(duration > 5)
        #expect(duration <= 30)
    }

    @Test func samplingNeverReturnsDuplicatesOrExceedsTheLimit() {
        for count in 1...40 {
            let sampled = ReelStoryboard.sample(photos(Array(1...count)), limit: 12)
            #expect(sampled.count <= min(count, 12))
            #expect(Set(sampled.map(\.dayNumber)).count == sampled.count, "duplicate frame at count \(count)")
        }
    }
}

/// The storyboard tests above prove the *shape* of a reel. This proves the thing it
/// produces is actually a video a phone will play — the encoder is where this feature
/// silently fails, and a reel that won't open is worse than no reel at all.
@MainActor
struct ReelVideoWriterTests {

    /// Small on purpose: a full 1080x1920 clip takes ~45s through the simulator's
    /// software encoder. The drawing and encoding paths are identical at any size.
    static let testSize = CGSize(width: 270, height: 480)

    private func still(_ color: UIColor, duration: Double) throws -> ReelVideoWriter.Still {
        let size = Self.testSize
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let cgImage = try #require(image.cgImage)
        return ReelVideoWriter.Still(image: cgImage, duration: duration)
    }

    @Test func writesAPlayableMP4OfTheExpectedLength() async throws {
        let stills = [
            try still(.systemOrange, duration: 0.5),
            try still(.black, duration: 0.5),
        ]

        let url = try await ReelVideoWriter.write(stills: stills, size: Self.testSize)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(FileManager.default.fileExists(atPath: url.path))
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        #expect(size > 0, "encoder produced an empty file")

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        #expect(tracks.count == 1)

        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 1.0) < 0.2, "expected ~1s, got \(duration)")

        let naturalSize = try await #require(tracks.first).load(.naturalSize)
        #expect(naturalSize == Self.testSize)
    }

    @Test func refusesToWriteAnEmptyReel() async {
        await #expect(throws: ReelVideoError.self) {
            _ = try await ReelVideoWriter.write(stills: [])
        }
    }
}

/// End-to-end: the path the button actually takes. Storyboard, SwiftUI rasterization and
/// encoding each work in isolation above; this is the one that catches them not fitting
/// together (a nil `ImageRenderer` result, a wrong proposed size, a dropped scene).
@MainActor
struct ReelComposerTests {

    /// See `ReelVideoWriterTests.testSize`.
    static let testSize = CGSize(width: 270, height: 480)

    @Test func buildsAPlayableReelFromStatsAlone() async throws {
        let input = ReelInput(
            name: "Alex",
            currentDay: 30,
            totalDays: 90,
            photos: [],
            daysShownUp: 27,
            longestStreak: 9,
            habitsKept: 3,
            referralCode: "AB12CD"
        )

        var lastProgress = 0.0
        let reel = try await ReelComposer.make(from: input, size: Self.testSize) { lastProgress = $0 }
        defer { try? FileManager.default.removeItem(at: reel.url) }

        #expect(reel.sceneCount == ReelStoryboard.scenes(for: input).count)
        #expect(lastProgress > 0.9, "progress must actually reach the end")
        #expect(reel.poster.size == Self.testSize)

        let asset = AVURLAsset(url: reel.url)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - reel.duration) < 0.3)
    }

    /// Photos can be deleted from Settings at any time. A reel referencing a missing file
    /// must skip that frame, not render a black hole in the middle of the story.
    @Test func skipsPhotoScenesWhoseFileIsGone() async throws {
        let input = ReelInput(
            name: "Alex",
            currentDay: 10,
            totalDays: 90,
            photos: [ReelInput.Photo(fileName: "does-not-exist.jpg", dayNumber: 3)],
            daysShownUp: 8,
            longestStreak: 4,
            habitsKept: 2,
            referralCode: "AB12CD"
        )

        let reel = try await ReelComposer.make(from: input, size: Self.testSize)
        defer { try? FileManager.default.removeItem(at: reel.url) }

        let storyboarded = ReelStoryboard.scenes(for: input).count
        #expect(reel.sceneCount == storyboarded - 1, "the missing photo frame should be dropped")
        #expect(reel.sceneCount >= 2)
    }
}
