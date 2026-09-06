import Foundation
import Vision
import UIKit

/// Real, on-device evidence analysis using Apple's Vision framework.
///
/// This replaces `MockAIProvider` as the shipping default. The mock returned a random
/// confidence and told users things like "strong evidence of an alert, awake face" about
/// a photo it had never looked at — fine as a development stub, dishonest in front of a
/// real user, and the app's headline feature.
///
/// Vision runs entirely on device: no API key, no backend, and the photo never leaves the
/// phone. That's a weaker signal than a large multimodal model, so the language stays
/// hedged and low-confidence results resolve to "couldn't verify" rather than a guess.
struct VisionAIProvider: AIProvider {

    func analyzeHabitEvidence(_ request: AIEvidenceRequest) async throws -> AIEvidenceAnalysis {
        guard let cgImage = request.image.cgImage else { throw AIProviderError.invalidImage }
        let orientation = CGImagePropertyOrientation(request.image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            // Vision is CPU/ANE heavy — keep it off the main thread.
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let analysis = try Self.analyze(
                        cgImage: cgImage,
                        orientation: orientation,
                        kind: request.habitKind
                    )
                    continuation.resume(returning: analysis)
                } catch {
                    // CoreML's inference engine failing to start is distinct from a bad
                    // photo, and telling the user their image was unreadable would be wrong.
                    let text = String(describing: error)
                    let engineFailed = text.contains("espresso")
                        || text.contains("inference context")
                    continuation.resume(
                        throwing: engineFailed
                            ? AIProviderError.analysisUnavailable
                            : AIProviderError.analysisFailed(text)
                    )
                }
            }
        }
    }

    // MARK: - Analysis

    private static func analyze(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        kind: VerificationHabitKind
    ) throws -> AIEvidenceAnalysis {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        switch kind {
        case .wakeUp:
            return try wakeUp(handler: handler)
        case .workout:
            return try scene(
                handler: handler,
                wanted: ["gym", "exercise", "weight", "dumbbell", "barbell", "treadmill",
                         "yoga", "sport", "running", "bicycle", "fitness"],
                positive: "Looks like a workout in progress.",
                positiveDetail: "Vision matched gym or exercise content in the photo.",
                negative: "Not quite enough evidence here.",
                negativeDetail: "Nothing clearly exercise-related was recognised. A wider shot of the equipment or space usually helps.",
                alsoAcceptPerson: true
            )
        case .reading:
            return try reading(handler: handler)
        case .water:
            return try scene(
                handler: handler,
                wanted: ["bottle", "water", "glass", "drink", "cup", "mug", "beverage"],
                positive: "Looks good — hydration logged.",
                positiveDetail: "Vision matched a bottle or drinking vessel in frame.",
                negative: "Couldn't confidently verify this.",
                negativeDetail: "No bottle or glass was clearly recognised. Try framing it a little more directly.",
                alsoAcceptPerson: false
            )
        case .custom:
            return try custom(handler: handler)
        }
    }

    /// Wake-up: a face, upright, with open eyes. Eye openness is estimated from landmark
    /// geometry, which is a genuine signal but not a certainty — hence the hedged copy.
    private static func wakeUp(handler: VNImageRequestHandler) throws -> AIEvidenceAnalysis {
        let request = VNDetectFaceLandmarksRequest()
        try handler.perform([request])

        guard let face = (request.results ?? []).max(by: { $0.boundingBox.area < $1.boundingBox.area }) else {
            return AIEvidenceAnalysis(
                confidence: 0.1,
                looksPlausible: false,
                shortMessage: "Couldn't find a face.",
                explanation: "No face was detected, so there's nothing to check. Try a photo of yourself with a bit more light."
            )
        }

        let quality = face.faceCaptureQuality.map(Double.init) ?? 0.5
        let openness = eyeOpenness(face)
        // Face presence is the bulk of the signal; eye openness refines it.
        let confidence = min(0.94, 0.45 + quality * 0.25 + openness * 0.3)

        if openness < 0.18 {
            return AIEvidenceAnalysis(
                confidence: confidence * 0.6,
                looksPlausible: false,
                shortMessage: "Eyes look closed.",
                explanation: "A face was detected, but the eyes appear shut. Worth another try once you're properly up."
            )
        }

        return AIEvidenceAnalysis(
            confidence: confidence,
            looksPlausible: confidence >= 0.7,
            shortMessage: "Looks like you're awake 👀",
            explanation: "A face was detected with open eyes — consistent with a wake-up check-in, though it can't prove the time of day."
        )
    }

    /// Reading: recognised text is the strongest available cue, backed by book-like scene labels.
    private static func reading(handler: VNImageRequestHandler) throws -> AIEvidenceAnalysis {
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .fast
        let classifyRequest = VNClassifyImageRequest()
        try handler.perform([textRequest, classifyRequest])

        let lines = (textRequest.results ?? []).count
        let labelScore = bestScore(
            in: classifyRequest,
            matching: ["book", "text", "paper", "magazine", "newspaper", "document", "page"]
        )

        // Plenty of text on the page is itself good evidence of reading material.
        let textScore = min(Double(lines) / 12.0, 1.0)
        let confidence = min(0.93, 0.25 + textScore * 0.45 + labelScore * 0.35)

        if confidence < 0.55 {
            return AIEvidenceAnalysis(
                confidence: confidence,
                looksPlausible: false,
                shortMessage: "Couldn't confidently verify this.",
                explanation: "No book or readable text was clearly recognised. Getting the page or cover in frame usually helps."
            )
        }

        return AIEvidenceAnalysis(
            confidence: confidence,
            looksPlausible: true,
            shortMessage: "Looks like reading time.",
            explanation: lines > 0
                ? "Readable text was recognised in the photo, consistent with a book or page."
                : "The scene matched reading material."
        )
    }

    /// Generic scene classification against a set of wanted labels.
    private static func scene(
        handler: VNImageRequestHandler,
        wanted: [String],
        positive: String,
        positiveDetail: String,
        negative: String,
        negativeDetail: String,
        alsoAcceptPerson: Bool
    ) throws -> AIEvidenceAnalysis {
        let classify = VNClassifyImageRequest()
        var requests: [VNRequest] = [classify]

        let bodyPose = VNDetectHumanBodyPoseRequest()
        if alsoAcceptPerson { requests.append(bodyPose) }
        try handler.perform(requests)

        var score = bestScore(in: classify, matching: wanted)
        if alsoAcceptPerson, !(bodyPose.results ?? []).isEmpty {
            // A person in frame supports a workout claim without proving it.
            score = max(score, 0.55)
        }

        let confidence = min(0.92, 0.2 + score * 0.72)
        guard confidence >= 0.55 else {
            return AIEvidenceAnalysis(
                confidence: confidence,
                looksPlausible: false,
                shortMessage: negative,
                explanation: negativeDetail
            )
        }
        return AIEvidenceAnalysis(
            confidence: confidence,
            looksPlausible: true,
            shortMessage: positive,
            explanation: positiveDetail
        )
    }

    /// Custom habits have no known target, so this reports what was actually recognised
    /// rather than pretending to judge whether it matches the habit.
    private static func custom(handler: VNImageRequestHandler) throws -> AIEvidenceAnalysis {
        let classify = VNClassifyImageRequest()
        try handler.perform([classify])

        let top = (classify.results ?? [])
            .filter { $0.hasMinimumRecall(0.4, forPrecision: 0.6) }
            .prefix(3)
            .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }

        guard !top.isEmpty else {
            return AIEvidenceAnalysis(
                confidence: 0.3,
                looksPlausible: false,
                shortMessage: "Couldn't make much out.",
                explanation: "Nothing recognisable was identified in the photo. It's saved as your evidence either way."
            )
        }

        return AIEvidenceAnalysis(
            confidence: 0.72,
            looksPlausible: true,
            shortMessage: "Photo received.",
            explanation: "Recognised: \(top.joined(separator: ", ")). Fix Me can't judge whether that matches your habit, so this is logged as your own evidence."
        )
    }

    // MARK: - Helpers

    private static func bestScore(in request: VNClassifyImageRequest, matching wanted: [String]) -> Double {
        let results = request.results ?? []
        var best = 0.0
        for observation in results {
            let identifier = observation.identifier.lowercased()
            guard wanted.contains(where: { identifier.contains($0) }) else { continue }
            best = max(best, Double(observation.confidence))
        }
        return best
    }

    /// Eye-aspect-ratio style estimate: eye height relative to width. Open eyes are
    /// rounder, closed eyes flatten toward a line.
    private static func eyeOpenness(_ face: VNFaceObservation) -> Double {
        guard let landmarks = face.landmarks else { return 0.5 }
        let ratios = [landmarks.leftEye, landmarks.rightEye].compactMap { region -> Double? in
            guard let points = region?.normalizedPoints, points.count > 3 else { return nil }
            let xs = points.map { Double($0.x) }
            let ys = points.map { Double($0.y) }
            let width = (xs.max() ?? 0) - (xs.min() ?? 0)
            let height = (ys.max() ?? 0) - (ys.min() ?? 0)
            guard width > 0 else { return nil }
            return height / width
        }
        guard !ratios.isEmpty else { return 0.5 }
        return min(ratios.reduce(0, +) / Double(ratios.count) / 0.35, 1.0)
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
