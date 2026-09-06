import Foundation
import UIKit

/// The application-facing verification contract. Wraps an `AIProvider` and translates
/// its hedged, raw output into a `VerificationOutcome` the UI can render directly.
protocol HabitVerificationService {
    func verifyWakeUpPhoto(_ image: UIImage) async -> VerificationOutcome
    func verifyWorkoutPhoto(_ image: UIImage) async -> VerificationOutcome
    func verifyReadingPhoto(_ image: UIImage) async -> VerificationOutcome
    func verifyWaterPhoto(_ image: UIImage) async -> VerificationOutcome
    func verifyCustomPhoto(_ image: UIImage, habitName: String) async -> VerificationOutcome
}

/// UI-ready verification result. Distinct from the persisted `VerificationResult` SwiftData
/// model — this is the transient outcome of one attempt, which the caller then persists.
struct VerificationOutcome {
    let status: VerificationStatus
    let confidence: Double
    let headline: String
    let explanation: String
    let timestamp: Date

    static func failure(_ message: String) -> VerificationOutcome {
        VerificationOutcome(
            status: .unableToVerify,
            confidence: 0,
            headline: "Couldn't verify that right now.",
            explanation: message,
            timestamp: .now
        )
    }
}

/// Default implementation, backed by an injected `AIProvider` (mock by default).
struct AIHabitVerificationService: HabitVerificationService {
    let provider: AIProvider

    init(provider: AIProvider = VisionAIProvider()) {
        self.provider = provider
    }

    func verifyWakeUpPhoto(_ image: UIImage) async -> VerificationOutcome {
        await verify(image, kind: .wakeUp)
    }

    func verifyWorkoutPhoto(_ image: UIImage) async -> VerificationOutcome {
        await verify(image, kind: .workout)
    }

    func verifyReadingPhoto(_ image: UIImage) async -> VerificationOutcome {
        await verify(image, kind: .reading)
    }

    func verifyWaterPhoto(_ image: UIImage) async -> VerificationOutcome {
        await verify(image, kind: .water)
    }

    func verifyCustomPhoto(_ image: UIImage, habitName: String) async -> VerificationOutcome {
        await verify(image, kind: .custom(habitName))
    }

    private func verify(_ image: UIImage, kind: VerificationHabitKind) async -> VerificationOutcome {
        do {
            let analysis = try await provider.analyzeHabitEvidence(
                AIEvidenceRequest(image: image, habitKind: kind, capturedAt: .now)
            )
            let status: VerificationStatus = {
                if analysis.confidence >= 0.85 { return .verified }
                if analysis.confidence >= 0.7 { return .needsReview }
                return .unableToVerify
            }()
            return VerificationOutcome(
                status: status,
                confidence: analysis.confidence,
                headline: analysis.shortMessage,
                explanation: analysis.explanation,
                timestamp: .now
            )
        } catch {
            return .failure((error as? LocalizedError)?.errorDescription ?? "Something went wrong. Your habit is still here.")
        }
    }
}
