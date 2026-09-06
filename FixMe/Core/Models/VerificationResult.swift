import Foundation
import SwiftData

/// The outcome of an AI or automated verification attempt for a habit completion.
@Model
final class VerificationResult {
    var id: UUID
    var status: VerificationStatus
    var confidence: Double        // 0...1
    var evidenceSummary: String   // short human-readable evidence description
    var explanation: String       // AI/system explanation shown to the user
    var timestamp: Date
    /// Local filesystem reference to the captured image, if any. Nil once the user deletes it.
    var imageFileName: String?
    var source: VerificationType

    init(
        id: UUID = UUID(),
        status: VerificationStatus,
        confidence: Double,
        evidenceSummary: String,
        explanation: String,
        timestamp: Date = .now,
        imageFileName: String? = nil,
        source: VerificationType
    ) {
        self.id = id
        self.status = status
        self.confidence = confidence
        self.evidenceSummary = evidenceSummary
        self.explanation = explanation
        self.timestamp = timestamp
        self.imageFileName = imageFileName
        self.source = source
    }
}
