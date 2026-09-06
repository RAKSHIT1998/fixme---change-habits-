import Foundation
import Observation
import SwiftData

/// Drives the Today screen: resolves (or lazily creates) today's `HabitCompletion` for each
/// habit, applies manual/HealthKit progress, and awards XP/streak updates on completion.
@MainActor
@Observable
final class TodayViewModel {
    private let modelContext: ModelContext
    private let services: ServiceContainer

    var lastXPAward: Int?
    var celebratingFullDay = false

    init(modelContext: ModelContext, services: ServiceContainer) {
        self.modelContext = modelContext
        self.services = services
    }

    // MARK: - Completion lookup

    func completion(for habit: Habit, on date: Date = .now) -> HabitCompletion {
        if let existing = habit.completion(on: date) {
            return existing
        }
        let new = HabitCompletion(date: date)
        new.habit = habit
        habit.completions.append(new)
        modelContext.insert(new)
        return new
    }

    func state(for habit: Habit) -> HabitDayState {
        // A quit habit is kept by default and broken by a logged relapse — the opposite
        // of a build habit, which starts unfinished and has to be earned. Resolved here
        // rather than by writing daily completion rows, so an untouched quit habit still
        // counts toward the day.
        if habit.isQuit {
            return habit.relapsed(on: .now) ? .missed : .completed
        }
        return completion(for: habit).state
    }

    func progress(for habit: Habit) -> Double {
        if habit.isQuit { return habit.relapsed(on: .now) ? 0 : 1 }
        guard habit.goalTargetValue > 0 else { return completion(for: habit).state.isDone ? 1 : 0 }
        return min(completion(for: habit).progressValue / habit.goalTargetValue, 1)
    }

    // MARK: - Manual completion (reading, journaling, custom "mark done" habits)

    func markManualComplete(_ habit: Habit) {
        let entry = completion(for: habit)
        guard !entry.state.isDone else { return }
        entry.progressValue = max(entry.progressValue, habit.goalTargetValue)
        finish(entry, habit: habit, verified: false)
    }

    /// Adds `delta` toward the goal (e.g. +250ml of water). Auto-completes at goal.
    func addProgress(_ habit: Habit, delta: Double) {
        let entry = completion(for: habit)
        guard !entry.state.isDone else { return }
        entry.progressValue = min(entry.progressValue + delta, habit.goalTargetValue)
        if entry.state == .notStarted { entry.state = .inProgress }
        Haptics.impact(.light)
        if entry.progressValue >= habit.goalTargetValue {
            finish(entry, habit: habit, verified: false)
        }
    }

    /// Applies a live HealthKit reading (e.g. today's step count) to a healthKit-verified habit.
    func syncHealthKitProgress(_ habit: Habit, value: Double) {
        guard habit.verificationType == .healthKit || habit.verificationType == .hybrid else { return }
        let entry = completion(for: habit)
        guard !entry.state.isDone else { return }
        entry.progressValue = value
        if value > 0 && entry.state == .notStarted { entry.state = .inProgress }
        if habit.goalTargetValue > 0 && value >= habit.goalTargetValue {
            finish(entry, habit: habit, verified: true)
        }
    }

    // MARK: - AI photo verification

    func beginWaitingForProof(_ habit: Habit) {
        completion(for: habit).state = .waitingForProof
    }

    func applyVerification(_ habit: Habit, outcome: VerificationOutcome, imageFileName: String?) {
        let entry = completion(for: habit)
        let result = VerificationResult(
            status: outcome.status,
            confidence: outcome.confidence,
            evidenceSummary: outcome.headline,
            explanation: outcome.explanation,
            imageFileName: imageFileName,
            source: .photoAI
        )
        entry.verification = result
        modelContext.insert(result)

        switch outcome.status {
        case .verified, .needsReview:
            entry.progressValue = max(entry.progressValue, habit.goalTargetValue)
            finish(entry, habit: habit, verified: outcome.status == .verified)
        case .rejected, .unableToVerify:
            entry.state = .inProgress
        }
        services.analytics.track(.habitVerified(name: habit.name, status: outcome.status))
    }

    // MARK: - Completion + rewards

    private func finish(_ entry: HabitCompletion, habit: Habit, verified: Bool) {
        entry.state = verified ? .verified : .completed
        entry.completedAt = .now
        let xp = XPService.awardForCompletion(verified: verified)
        entry.xpAwarded = xp
        lastXPAward = xp
        Haptics.notify(.success)
        services.analytics.track(.habitCompleted(name: habit.name))

        if let journey = habit.journey, let user = journey.owner {
            user.totalXP += xp
            BadgeEvaluator.evaluate(journey: journey, user: user, context: modelContext)
            WidgetSnapshotPublisher.publish(journey: journey)
        }
        try? modelContext.save()
    }

    // MARK: - Day-level aggregates

    func dayCompletionFraction(habits: [Habit]) -> Double {
        guard !habits.isEmpty else { return 0 }
        let done = habits.filter { state(for: $0).isDone }.count
        return Double(done) / Double(habits.count)
    }

    func dailyScore(habits: [Habit]) -> Int {
        Int((dayCompletionFraction(habits: habits) * 100).rounded())
    }
}
