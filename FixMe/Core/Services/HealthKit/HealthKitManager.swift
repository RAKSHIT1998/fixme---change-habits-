import Foundation
import HealthKit
import Observation

/// Thin, focused wrapper over HealthKit. Requests only the read types this app actually
/// uses. Every entry point degrades gracefully — a denied/unavailable HealthKit never
/// blocks the rest of the app; callers should fall back to manual completion.
@Observable
final class HealthKitManager {
    private let store = HKHealthStore()

    private(set) var isAuthorized = false
    private(set) var todaySteps: Double = 0
    private(set) var todayActiveEnergy: Double = 0
    private(set) var todayExerciseMinutes: Double = 0
    private(set) var lastNightSleepHours: Double = 0
    private(set) var hasRecentWorkout = false

    static var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType(),
        ]
        types.insert(HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!)
        return types
    }

    /// Requests read authorization. Safe to call repeatedly; safe on simulators without Health data.
    func requestAuthorization() async -> Bool {
        guard Self.isHealthDataAvailable else {
            isAuthorized = false
            return false
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            return true
        } catch {
            isAuthorized = false
            return false
        }
    }

    func refreshTodayMetrics() async {
        guard Self.isHealthDataAvailable else { return }
        async let steps = sumToday(.stepCount, unit: .count())
        async let energy = sumToday(.activeEnergyBurned, unit: .kilocalorie())
        async let exercise = sumToday(.appleExerciseTime, unit: .minute())
        todaySteps = await steps
        todayActiveEnergy = await energy
        todayExerciseMinutes = await exercise
        hasRecentWorkout = await recentWorkoutExists()
    }

    private func sumToday(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func recentWorkoutExists() async -> Bool {
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: !(samples ?? []).isEmpty)
            }
            store.execute(query)
        }
    }
}
