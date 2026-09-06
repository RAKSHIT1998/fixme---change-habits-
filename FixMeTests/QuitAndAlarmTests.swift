import Testing
import Foundation
import SwiftData
@testable import FixMe

@MainActor
struct QuitProgressTests {

    private func makeQuitHabit(daysClean: Double) -> Habit {
        Habit(
            name: "No smoking", iconSystemName: "nosign", category: .health,
            verificationType: .manual, goalDescription: "Stay smoke-free",
            kind: .quit, quitProgramID: "smoking",
            quitStartDate: Date.now.addingTimeInterval(-daysClean * 86_400),
            unitsPerDay: 10, costPerUnit: 0.5
        )
    }

    @Test func cleanTimeAndMoneyTrackTogether() {
        let habit = makeQuitHabit(daysClean: 10)
        let days = QuitProgressCalculator.cleanTime(for: habit) / 86_400
        #expect(abs(days - 10) < 0.01)
        // 10 days × 10 cigarettes × $0.50
        #expect(abs(habit.moneySaved() - 50) < 0.5)
        #expect(habit.unitsAvoided() == 100)
    }

    @Test func formatterProducesReadableDurations() {
        #expect(QuitProgressCalculator.formatted(0) == "0m")
        #expect(QuitProgressCalculator.formatted(90 * 60) == "1h 30m")
        #expect(QuitProgressCalculator.formatted(2 * 86_400 + 3 * 3_600) == "2d 3h 0m")
    }

    @Test func milestonesUnlockAsCleanTimeAccrues() {
        let fresh = makeQuitHabit(daysClean: 0)
        let twoWeeks = makeQuitHabit(daysClean: 14)

        #expect(QuitProgressCalculator.reachedMilestones(for: fresh).isEmpty)
        #expect(QuitProgressCalculator.reachedMilestones(for: twoWeeks).count > 3)
        #expect(QuitProgressCalculator.nextMilestone(for: twoWeeks) != nil)

        let progress = QuitProgressCalculator.progressToNextMilestone(for: twoWeeks)
        #expect(progress >= 0 && progress <= 1)
    }

    /// The rule the whole feature rests on: relapsing resets the current run and nothing
    /// else. If this ever regresses, the app punishes exactly the people it exists to help.
    @Test func relapsePreservesHistoryAndOnlyResetsTheCurrentRun() throws {
        let container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        defer { withExtendedLifetime(container) {} }   // context does not retain its container
        let context = container.mainContext

        let habit = makeQuitHabit(daysClean: 12)
        context.insert(habit)

        QuitProgressCalculator.recordRelapse(for: habit, trigger: "Stressful week", context: context)

        // Current run restarts...
        #expect(QuitProgressCalculator.cleanTime(for: habit) < 60)
        // ...but everything earned survives.
        #expect(habit.relapses.count == 1)
        #expect(QuitProgressCalculator.attemptCount(for: habit) == 2)
        #expect(abs(QuitProgressCalculator.longestRun(for: habit) / 86_400 - 12) < 0.01)
        #expect(abs(QuitProgressCalculator.totalCleanTime(for: habit) / 86_400 - 12) < 0.01)
        #expect(habit.relapses.first?.trigger == "Stressful week")
    }

    @Test func totalCleanTimeAccumulatesAcrossAttempts() throws {
        let container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        defer { withExtendedLifetime(container) {} }   // context does not retain its container
        let context = container.mainContext

        let habit = makeQuitHabit(daysClean: 5)
        context.insert(habit)
        QuitProgressCalculator.recordRelapse(for: habit, trigger: nil, context: context)

        // Second run of 3 days, then another relapse.
        habit.quitStartDate = Date.now.addingTimeInterval(-3 * 86_400)
        QuitProgressCalculator.recordRelapse(for: habit, trigger: nil, context: context)

        #expect(QuitProgressCalculator.attemptCount(for: habit) == 3)
        #expect(abs(QuitProgressCalculator.totalCleanTime(for: habit) / 86_400 - 8) < 0.05)
        #expect(abs(QuitProgressCalculator.longestRun(for: habit) / 86_400 - 5) < 0.05)
    }

    @Test func quitHabitCountsAsKeptUntilARelapseIsLogged() {
        let habit = makeQuitHabit(daysClean: 3)
        #expect(!habit.relapsed(on: .now))

        let event = RelapseEvent(date: .now)
        event.habit = habit
        habit.relapses.append(event)

        #expect(habit.relapsed(on: .now))
    }

    @Test func buildHabitsAreUnaffectedByQuitFields() {
        let habit = HabitCatalog.all[1].makeHabit()
        #expect(!habit.isQuit)
        #expect(habit.moneySaved() == 0)
        #expect(habit.unitsAvoided() == 0)
    }
}

@MainActor
struct AlarmTests {

    @Test func emptyWeekdaysMeansEveryDay() {
        #expect(HabitAlarm(weekdays: []).repeatsEveryDay)
        #expect(HabitAlarm(weekdays: [1, 2, 3, 4, 5, 6, 7]).repeatsEveryDay)
        #expect(!HabitAlarm(weekdays: [2, 4]).repeatsEveryDay)
    }

    @Test func repeatSummaryNamesCommonPatterns() {
        #expect(HabitAlarm(weekdays: []).repeatSummary == "Every day")
        #expect(HabitAlarm(weekdays: [2, 3, 4, 5, 6]).repeatSummary == "Weekdays")
        #expect(HabitAlarm(weekdays: [1, 7]).repeatSummary == "Weekends")
    }

    @Test func snoozeIntervalIsAlwaysPositive() {
        // A zero or negative snooze would make UNTimeIntervalNotificationTrigger throw.
        let alarm = HabitAlarm(snoozeMinutes: 0)
        #expect(max(alarm.snoozeMinutes, 1) * 60 > 0)
    }
}

@MainActor
struct QuitHabitsAreNeverPaywalledTests {

    private func gate() -> PremiumGate { PremiumGate(subscriptions: SubscriptionService()) }

    private func quitHabit(_ name: String, order: Int) -> Habit {
        Habit(name: name, iconSystemName: "nosign", category: .health,
              verificationType: .manual, goalDescription: "Stay clean",
              sortOrder: order, kind: .quit, quitProgramID: "smoking", quitStartDate: .now)
    }

    /// Regression: a sobriety counter must never be paused for hitting a billing limit.
    @Test func quitHabitsStayActiveEvenPastTheFreeLimit() {
        var habits: [Habit] = (0..<PremiumGate.freeHabitLimit).map {
            HabitCatalog.all[$0].makeHabit(sortOrder: $0)
        }
        habits.append(quitHabit("No smoking", order: 99))

        let split = gate().partition(habits)

        #expect(split.paused.isEmpty)
        #expect(split.active.contains { $0.isQuit })
    }

    @Test func buildHabitsBeyondTheLimitStillPause() {
        let habits: [Habit] = (0..<(PremiumGate.freeHabitLimit + 2)).map {
            HabitCatalog.all[$0].makeHabit(sortOrder: $0)
        }
        let split = gate().partition(habits)

        #expect(split.active.count == PremiumGate.freeHabitLimit)
        #expect(split.paused.count == 2)
    }

    @Test func aQuitHabitCanAlwaysBeAdded() {
        let full: [Habit] = (0..<(PremiumGate.freeHabitLimit + 3)).map {
            HabitCatalog.all[$0].makeHabit(sortOrder: $0)
        }
        #expect(gate().canAddHabit(kind: .quit, existing: full))
        #expect(!gate().canAddHabit(kind: .build, existing: full))
    }
}
