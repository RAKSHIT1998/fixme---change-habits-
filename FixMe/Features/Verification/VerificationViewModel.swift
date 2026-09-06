import Foundation
import UIKit
import Observation

@Observable
final class VerificationViewModel {
    enum Phase: Equatable {
        case ready
        case captured
        case scanning
        case result(VerificationOutcomeBox)
    }

    /// Wraps `VerificationOutcome` for `Equatable` conformance (needed for SwiftUI `.animation`).
    struct VerificationOutcomeBox: Equatable {
        let outcome: VerificationOutcome
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.outcome.timestamp == rhs.outcome.timestamp }
    }

    var phase: Phase = .ready
    var capturedImage: UIImage?

    private let service: HabitVerificationService

    init(service: HabitVerificationService) {
        self.service = service
    }

    func setCaptured(_ image: UIImage) {
        capturedImage = image
        phase = .captured
    }

    func retake() {
        capturedImage = nil
        phase = .ready
    }

    @MainActor
    func submit(for habit: Habit) async {
        guard let image = capturedImage else { return }
        phase = .scanning
        let outcome = await verify(image: image, habit: habit)
        phase = .result(VerificationOutcomeBox(outcome: outcome))
        Haptics.notify(outcome.status == .verified ? .success : (outcome.status == .rejected ? .error : .warning))
    }

    private func verify(image: UIImage, habit: Habit) async -> VerificationOutcome {
        switch verificationKind(for: habit) {
        case .wakeUp: return await service.verifyWakeUpPhoto(image)
        case .workout: return await service.verifyWorkoutPhoto(image)
        case .reading: return await service.verifyReadingPhoto(image)
        case .water: return await service.verifyWaterPhoto(image)
        case .custom: return await service.verifyCustomPhoto(image, habitName: habit.name)
        }
    }

    private func verificationKind(for habit: Habit) -> VerificationHabitKind {
        let name = habit.name.lowercased()
        if name.contains("wake") { return .wakeUp }
        if name.contains("workout") || name.contains("run") || name.contains("stretch") { return .workout }
        if name.contains("read") { return .reading }
        if name.contains("water") { return .water }
        return .custom(habit.name)
    }
}
