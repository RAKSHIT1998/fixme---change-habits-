import Foundation

/// Whether a habit is something you're building or something you're stopping.
/// Quit habits invert the whole model: progress is continuous clean time rather than a
/// daily checkbox, and the failure mode is a relapse rather than a missed day.
enum HabitKind: String, Codable, CaseIterable {
    case build
    case quit
}

/// A thing someone is quitting, with the recovery timeline shown on their tracker.
struct QuitProgram: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
    let unitName: String          // "cigarettes", "drinks"
    let unitCostHint: String      // placeholder text for the cost field
    let defaultUnitsPerDay: Double
    let defaultCostPerUnit: Double
    /// Shown at setup when stopping carries real medical risk. Empty for programs where it doesn't.
    let safetyNote: String
    let milestones: [RecoveryMilestone]

    static let smoking = QuitProgram(
        id: "smoking",
        title: "Smoking",
        emoji: "🚭",
        unitName: "cigarettes",
        unitCostHint: "Cost per cigarette",
        defaultUnitsPerDay: 10,
        defaultCostPerUnit: 0.5,
        safetyNote: "",
        milestones: [
            RecoveryMilestone(hours: 0.33, title: "Heart rate settles", detail: "Heart rate and blood pressure start returning toward normal."),
            RecoveryMilestone(hours: 12, title: "Carbon monoxide clears", detail: "Carbon monoxide in your blood drops toward a normal level."),
            RecoveryMilestone(hours: 24, title: "Heart risk starts falling", detail: "The elevated risk of heart attack begins to decrease."),
            RecoveryMilestone(hours: 48, title: "Taste and smell return", detail: "Nerve endings begin to recover; food starts tasting like food again."),
            RecoveryMilestone(hours: 72, title: "Breathing gets easier", detail: "Bronchial tubes relax and lung capacity increases."),
            RecoveryMilestone(hours: 24 * 14, title: "Circulation improves", detail: "Walking and exercise start to feel noticeably easier."),
            RecoveryMilestone(hours: 24 * 30, title: "One month", detail: "Lung function improves and coughing tends to decrease."),
            RecoveryMilestone(hours: 24 * 90, title: "Three months", detail: "Significant improvement in lung function."),
            RecoveryMilestone(hours: 24 * 365, title: "One year", detail: "Excess risk of coronary heart disease is about half that of a smoker."),
            RecoveryMilestone(hours: 24 * 365 * 5, title: "Five years", detail: "Stroke risk falls substantially."),
        ]
    )

    static let alcohol = QuitProgram(
        id: "alcohol",
        title: "Alcohol",
        emoji: "🚫🍺",
        unitName: "drinks",
        unitCostHint: "Cost per drink",
        defaultUnitsPerDay: 3,
        defaultCostPerUnit: 6,
        safetyNote: "If you drink heavily or every day, stopping suddenly can be medically dangerous — withdrawal can cause seizures. Please talk to a doctor about the safest way to stop. Fix Me is a tracker, not medical care.",
        milestones: [
            RecoveryMilestone(hours: 24, title: "First day", detail: "Blood sugar begins to stabilize."),
            RecoveryMilestone(hours: 72, title: "Three days", detail: "For many people this is the hardest stretch. It does ease."),
            RecoveryMilestone(hours: 24 * 7, title: "One week", detail: "Sleep quality and hydration typically start improving."),
            RecoveryMilestone(hours: 24 * 14, title: "Two weeks", detail: "Stomach irritation and reflux often settle down."),
            RecoveryMilestone(hours: 24 * 30, title: "One month", detail: "Liver fat is commonly reduced; skin and energy often improve."),
            RecoveryMilestone(hours: 24 * 90, title: "Three months", detail: "Continued liver recovery and steadier energy and mood."),
            RecoveryMilestone(hours: 24 * 180, title: "Six months", detail: "Substantial liver recovery for many people."),
            RecoveryMilestone(hours: 24 * 365, title: "One year", detail: "Lower long-term risk of liver disease and several cancers."),
        ]
    )

    static let vaping = QuitProgram(
        id: "vaping",
        title: "Vaping",
        emoji: "💨",
        unitName: "pods",
        unitCostHint: "Cost per pod",
        defaultUnitsPerDay: 0.5,
        defaultCostPerUnit: 8,
        safetyNote: "",
        milestones: [
            RecoveryMilestone(hours: 0.33, title: "Heart rate settles", detail: "Heart rate and blood pressure start returning toward normal."),
            RecoveryMilestone(hours: 24, title: "Nicotine clearing", detail: "Most nicotine has left your system. Cravings peak around now."),
            RecoveryMilestone(hours: 72, title: "Three days", detail: "The physical withdrawal peak is usually behind you."),
            RecoveryMilestone(hours: 24 * 14, title: "Two weeks", detail: "Breathing and circulation typically improve."),
            RecoveryMilestone(hours: 24 * 30, title: "One month", detail: "Lung irritation and coughing tend to decrease."),
            RecoveryMilestone(hours: 24 * 90, title: "Three months", detail: "Cravings are usually far less frequent and less intense."),
        ]
    )

    static let custom = QuitProgram(
        id: "custom",
        title: "Something else",
        emoji: "🎯",
        unitName: "times",
        unitCostHint: "Cost each time",
        defaultUnitsPerDay: 1,
        defaultCostPerUnit: 0,
        safetyNote: "",
        milestones: [
            RecoveryMilestone(hours: 24, title: "One day"),
            RecoveryMilestone(hours: 72, title: "Three days"),
            RecoveryMilestone(hours: 24 * 7, title: "One week"),
            RecoveryMilestone(hours: 24 * 30, title: "One month"),
            RecoveryMilestone(hours: 24 * 90, title: "Three months"),
            RecoveryMilestone(hours: 24 * 365, title: "One year"),
        ]
    )

    static let all: [QuitProgram] = [smoking, alcohol, vaping, custom]

    static func program(id: String?) -> QuitProgram? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

/// A point on a quit program's recovery timeline.
///
/// These are widely published general timelines (the kind printed by public health
/// bodies), shown for motivation. They describe typical patterns, not a prediction about
/// any individual — the UI labels them as such rather than implying a personal diagnosis.
struct RecoveryMilestone: Identifiable, Hashable {
    let hours: Double
    let title: String
    var detail: String = ""

    var id: Double { hours }

    var elapsedLabel: String {
        switch hours {
        case ..<1: return "\(Int(hours * 60)) min"
        case ..<24: return "\(Int(hours)) hours"
        case ..<(24 * 30): return "\(Int(hours / 24)) days"
        case ..<(24 * 365): return "\(Int(hours / 24 / 30)) months"
        default: return "\(Int(hours / 24 / 365)) year\(hours >= 24 * 365 * 2 ? "s" : "")"
        }
    }
}
