import Foundation
import SwiftData
import WidgetKit

/// Keeps the home screen widget in step with the app.
///
/// This previously ran only when a habit was *completed*, so a fresh journey published
/// nothing at all and the widget fell back to sample data — showing Day 17 to someone on
/// Day 1. Publishing is now cheap enough (a UserDefaults write) to do on every meaningful
/// change, including simply opening the app.
@MainActor
enum WidgetSnapshotPublisher {

    /// Builds the snapshot for a journey. Pure, so it can be tested without a widget.
    static func snapshot(for journey: Journey, now: Date = .now) -> WidgetSnapshot {
        let habits = journey.habits.sorted { $0.sortOrder < $1.sortOrder }

        let done = habits.filter { habit in
            habit.isQuit
                ? !habit.relapsed(on: now)
                : (habit.completion(on: now)?.state.isDone ?? false)
        }
        let percent = habits.isEmpty
            ? 0
            : Int((Double(done.count) / Double(habits.count) * 100).rounded())

        let next = habits.first { habit in
            habit.isQuit
                ? false                                   // quit habits need no action
                : !(habit.completion(on: now)?.state.isDone ?? false)
        }

        return WidgetSnapshot(
            dayNumber: journey.dayNumber(for: now),
            totalDays: journey.lengthInDays,
            completionPercent: percent,
            currentStreak: habits.map { $0.currentStreak(today: now) }.max() ?? 0,
            nextHabitName: next?.name,
            updatedAt: now
        )
    }

    /// Publishes the active journey's state, or clears the widget when there isn't one.
    static func publish(from context: ModelContext) {
        let journeys = (try? context.fetch(FetchDescriptor<Journey>())) ?? []
        guard let journey = journeys.first(where: \.isActive) else {
            WidgetSnapshotStore.clear()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        publish(journey: journey)
    }

    static func publish(journey: Journey) {
        WidgetSnapshotStore.save(snapshot(for: journey))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
