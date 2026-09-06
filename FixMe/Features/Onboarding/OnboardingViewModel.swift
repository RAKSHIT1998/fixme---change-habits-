import Foundation
import Observation
import SwiftData
import SwiftUI

@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome, categories, habits, quitPrograms, commitment, journeyPreview, notifications, health, commit
    }

    var step: Step = .welcome
    var selectedCategories: Set<HabitCategory> = []
    var selectedHabitNames: Set<String> = []
    var commitmentSlider: Double = 0.5
    var selectedQuitProgramIDs: Set<String> = []
    var quitUnitsPerDay: [String: Double] = [:]
    var quitCostPerUnit: [String: Double] = [:]
    var notificationsGranted = false
    var healthGranted = false
    var startToday = true
    var name = ""

    /// Falls back rather than blocking the flow — a name is useful, not mandatory.
    var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "You" : trimmed
    }

    var commitmentLevel: CommitmentLevel { .from(sliderValue: commitmentSlider) }

    var suggestedHabits: [HabitBlueprint] {
        if selectedCategories.isEmpty { return HabitCatalog.all }
        return HabitCatalog.all.filter { selectedCategories.contains($0.category) }
    }

    var selectedBlueprints: [HabitBlueprint] {
        HabitCatalog.all.filter { selectedHabitNames.contains($0.name) }
    }

    var journeyStartDate: Date {
        startToday ? Date.now.startOfDay : Calendar.current.date(byAdding: .day, value: 1, to: .now.startOfDay) ?? .now
    }

    var journeyEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 89, to: journeyStartDate) ?? journeyStartDate
    }

    func toggleCategory(_ category: HabitCategory) {
        Haptics.selection()
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func toggleQuitProgram(_ program: QuitProgram) {
        Haptics.selection()
        if selectedQuitProgramIDs.contains(program.id) {
            selectedQuitProgramIDs.remove(program.id)
        } else {
            selectedQuitProgramIDs.insert(program.id)
            quitUnitsPerDay[program.id] = quitUnitsPerDay[program.id] ?? program.defaultUnitsPerDay
            quitCostPerUnit[program.id] = quitCostPerUnit[program.id] ?? program.defaultCostPerUnit
        }
    }

    func clearQuitPrograms() {
        Haptics.selection()
        selectedQuitProgramIDs.removeAll()
    }

    func toggleHabit(_ blueprint: HabitBlueprint) {
        Haptics.selection()
        if selectedHabitNames.contains(blueprint.name) {
            selectedHabitNames.remove(blueprint.name)
        } else {
            selectedHabitNames.insert(blueprint.name)
        }
    }

    func advance() {
        Haptics.impact(.light)
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation { step = next }
    }

    func back() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation { step = prev }
    }

    /// Creates the User + first Journey + selected Habits and persists them.
    @MainActor
    func persistJourney(context: ModelContext) {
        let user = User(name: resolvedName)
        user.settings = UserSettings(
            healthKitAuthorized: healthGranted,
            notificationsAuthorized: notificationsGranted
        )
        context.insert(user)

        let journey = Journey(
            startDate: journeyStartDate,
            commitmentLevel: commitmentLevel
        )
        journey.owner = user
        context.insert(journey)

        let blueprintsToUse = selectedBlueprints.isEmpty ? Array(HabitCatalog.all.prefix(4)) : selectedBlueprints
        for (index, blueprint) in blueprintsToUse.enumerated() {
            let habit = blueprint.makeHabit(sortOrder: index)
            habit.journey = journey
            context.insert(habit)
        }

        // Quit habits start their clean run the moment the journey begins.
        for (offset, programID) in selectedQuitProgramIDs.sorted().enumerated() {
            guard let program = QuitProgram.program(id: programID) else { continue }
            let habit = Habit(
                name: program.id == "custom" ? "Quit \(program.title.lowercased())" : "No \(program.title.lowercased())",
                iconSystemName: "nosign",
                category: .health,
                verificationType: .manual,
                goalDescription: "Stay \(program.title.lowercased())-free",
                sortOrder: blueprintsToUse.count + offset,
                kind: .quit,
                quitProgramID: program.id,
                quitStartDate: .now,
                unitsPerDay: quitUnitsPerDay[program.id] ?? program.defaultUnitsPerDay,
                costPerUnit: quitCostPerUnit[program.id] ?? program.defaultCostPerUnit
            )
            habit.journey = journey
            context.insert(habit)
        }

        try? context.save()
    }

    /// Flips the app into its main experience. Split from `persistJourney` so the paywall
    /// can sit between the two without risking a user losing their setup by dismissing it.
    @MainActor
    func finishOnboarding(appState: AppState) {
        appState.hasCompletedOnboarding = true
    }
}
