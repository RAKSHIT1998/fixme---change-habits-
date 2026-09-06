import Foundation
import UIKit

/// Abstraction over whatever model actually analyzes evidence photos.
/// Swap `MockAIProvider` for a real network-backed provider later without touching call sites.
/// No API keys live in this app target — a production provider should call a backend you control.
protocol AIProvider {
    func analyzeHabitEvidence(_ request: AIEvidenceRequest) async throws -> AIEvidenceAnalysis
}

struct AIEvidenceRequest {
    let image: UIImage
    let habitKind: VerificationHabitKind
    let capturedAt: Date
}

enum VerificationHabitKind {
    case wakeUp, workout, reading, water, custom(String)
}

/// Raw model output — deliberately hedged. The verification service maps this into
/// a user-facing `VerificationResult`.
struct AIEvidenceAnalysis {
    let confidence: Double   // 0...1 — never treat as certainty
    let looksPlausible: Bool
    let shortMessage: String
    let explanation: String
}

enum AIProviderError: LocalizedError {
    case networkUnavailable
    case invalidImage
    case timedOut
    /// Carries the underlying reason. Collapsing every failure into `invalidImage` hid
    /// the real cause and would have told users their photo was unreadable when the
    /// analyser itself was at fault.
    case analysisFailed(String)
    /// On-device vision models couldn't start. In practice this means the iOS Simulator
    /// on an Intel Mac, where CoreML's inference engine is unavailable.
    case analysisUnavailable

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "Couldn't reach the verification service."
        case .invalidImage: return "That image couldn't be read."
        case .timedOut: return "Verification took too long."
        case .analysisFailed(let reason): return "Couldn't analyse that photo: \(reason)"
        case .analysisUnavailable:
            #if targetEnvironment(simulator)
            return "On-device photo analysis can't run in the Simulator on an Intel Mac. Try it on a real device."
            #else
            return "On-device photo analysis isn't available right now."
            #endif
        }
    }
}
