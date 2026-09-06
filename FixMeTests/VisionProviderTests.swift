import Testing
import Foundation
import UIKit
import Vision
@testable import FixMe

/// Probes once whether Vision's CoreML-backed requests can actually run here. They can't
/// in the iOS Simulator on an Intel Mac, where the inference engine fails to start — so
/// these tests skip rather than reporting a failure that says nothing about the code.
enum VisionAvailability {
    @MainActor static let isWorking: Bool = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        guard let cgImage = image.cgImage else { return false }
        let request = VNClassifyImageRequest()
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            return true
        } catch {
            return false
        }
    }()
}

/// Guards the integrity problem these replaced: `MockAIProvider` returned a random
/// confidence and asserted things about photos it never examined.
@MainActor
@Suite(.enabled(if: VisionAvailability.isWorking,
                "Vision's on-device models can't start here — run on a device or an Apple Silicon Mac."))
struct VisionAIProviderTests {

    private let provider = VisionAIProvider()

    private func image(_ color: UIColor, size: CGSize = CGSize(width: 400, height: 400)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func textImage(_ text: String) -> UIImage {
        let size = CGSize(width: 800, height: 600)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 44),
                .foregroundColor: UIColor.black,
            ]
            text.draw(in: CGRect(x: 30, y: 30, width: size.width - 60, height: size.height - 60),
                      withAttributes: attributes)
        }
    }

    private func analyze(_ image: UIImage, _ kind: VerificationHabitKind) async throws -> AIEvidenceAnalysis {
        try await provider.analyzeHabitEvidence(
            AIEvidenceRequest(image: image, habitKind: kind, capturedAt: .now)
        )
    }

    /// The core of it: a blank wall is not a person waking up, and must not be verified.
    @Test func aBlankImageIsNotAcceptedAsAWakeUpPhoto() async throws {
        let result = try await analyze(image(.gray), .wakeUp)
        #expect(result.looksPlausible == false)
        #expect(result.confidence < 0.5)
        #expect(result.shortMessage.lowercased().contains("face"))
    }

    @Test func aBlankImageIsNotAcceptedAsWater() async throws {
        let result = try await analyze(image(.white), .water)
        #expect(result.looksPlausible == false)
    }

    /// Determinism is the sharpest available proof that nothing is being invented:
    /// the old provider returned a different confidence every single call.
    @Test func theSameImageAlwaysProducesTheSameVerdict() async throws {
        let sample = image(.darkGray)
        let first = try await analyze(sample, .wakeUp)
        let second = try await analyze(sample, .wakeUp)
        let third = try await analyze(sample, .wakeUp)

        #expect(first.confidence == second.confidence)
        #expect(second.confidence == third.confidence)
        #expect(first.shortMessage == second.shortMessage)
    }

    /// And it genuinely reads the pixels: a page of text scores far higher for a reading
    /// habit than a blank image does.
    @Test func aPageOfTextScoresHigherForReadingThanABlankImage() async throws {
        let blank = try await analyze(image(.white), .reading)
        let page = try await analyze(
            textImage("""
            Chapter One. The quick brown fox jumps over the lazy dog, and the \
            morning light fell across the page as she turned it slowly.
            """),
            .reading
        )

        #expect(page.confidence > blank.confidence)
        #expect(page.looksPlausible == true)
        #expect(blank.looksPlausible == false)
    }

    @Test func confidenceNeverClaimsCertainty() async throws {
        // Nothing on-device justifies a 100% claim, so the scale is deliberately capped.
        for kind in [VerificationHabitKind.wakeUp, .workout, .reading, .water, .custom("x")] {
            let result = try await analyze(textImage("Hello there"), kind)
            #expect(result.confidence <= 0.95)
            #expect(result.confidence >= 0)
        }
    }

    @Test func customHabitsReportWhatWasSeenRatherThanJudgingTheHabit() async throws {
        let result = try await analyze(image(.systemBlue), .custom("Practice guitar"))
        // It must never claim the photo proves an arbitrary habit it can't evaluate.
        #expect(!result.shortMessage.lowercased().contains("verified"))
    }
}
