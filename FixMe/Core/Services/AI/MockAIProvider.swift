import Foundation
import UIKit

/// Test and preview double. **Not for shipping.**
///
/// This returns a random confidence without examining the image, so any user-facing claim
/// it makes is fabricated. `VisionAIProvider` is the real implementation and the app's
/// default; this exists so tests and SwiftUI previews can run without touching Vision.
struct MockAIProvider: AIProvider {

    func analyzeHabitEvidence(_ request: AIEvidenceRequest) async throws -> AIEvidenceAnalysis {
        // Simulate on-device/network latency so the scanning UI has something real to show.
        try await Task.sleep(nanoseconds: UInt64.random(in: 900_000_000...1_600_000_000))

        guard request.image.cgImage != nil || request.image.ciImage != nil else {
            throw AIProviderError.invalidImage
        }

        // Deterministic-ish but varied confidence so the UI feels alive across repeated tries.
        let confidence = Double.random(in: 0.62...0.97)
        let plausible = confidence >= 0.7

        let (short, explanation) = message(for: request.habitKind, plausible: plausible, confidence: confidence)
        return AIEvidenceAnalysis(
            confidence: confidence,
            looksPlausible: plausible,
            shortMessage: short,
            explanation: explanation
        )
    }

    private func message(for kind: VerificationHabitKind, plausible: Bool, confidence: Double) -> (String, String) {
        switch kind {
        case .wakeUp:
            return plausible
                ? ("Looks like you're awake 👀", "Strong evidence of an alert, awake face consistent with a wake-up check-in.")
                : ("Couldn't confidently verify this.", "The photo doesn't give us enough to go on. Want to try another angle with more light?")
        case .workout:
            return plausible
                ? ("Looks like a workout in progress.", "Evidence is consistent with active movement or workout surroundings.")
                : ("Not quite enough evidence here.", "We couldn't confidently match this to a workout. A wider shot might help.")
        case .reading:
            return plausible
                ? ("Looks like reading time.", "Evidence is consistent with a book or reading material in frame.")
                : ("Couldn't confidently verify this.", "We didn't clearly spot a book. Try getting the cover or pages in frame.")
        case .water:
            return plausible
                ? ("Looks good — hydration logged.", "Evidence is consistent with a water bottle or glass in frame.")
                : ("Couldn't confidently verify this.", "Try framing the bottle or glass a little more clearly.")
        case .custom:
            return plausible
                ? ("Looks consistent with your habit.", "The evidence is reasonably consistent with what you're proving.")
                : ("Couldn't confidently verify this.", "Unable to confidently verify — you can try again or mark it manually.")
        }
    }
}
