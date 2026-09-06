import SwiftUI

struct DayHeaderView: View {
    let journey: Journey
    let completionFraction: Double
    var userName: String? = nil

    private var dayNumber: Int { journey.dayNumber() }

    var body: some View {
        VStack(spacing: FMTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let greeting {
                        Text(greeting)
                            .font(FMTheme.Typography.subheadline)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                    }
                    Text("DAY \(dayNumber) / \(journey.lengthInDays)")
                        .font(FMTheme.Typography.caption)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                    Text("\(journey.daysRemaining) days to go")
                        .font(FMTheme.Typography.title2)
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                }
                Spacer()
            }

            ZStack {
                ProgressRing(progress: completionFraction, size: 148)
                VStack(spacing: 2) {
                    Text("TODAY")
                        .font(FMTheme.Typography.caption)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                    Text("\(Int(completionFraction * 100))%")
                        .font(FMTheme.Typography.display(34))
                        .contentTransition(.numericText())
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                }
            }
            .padding(.vertical, FMTheme.Spacing.sm)

            Text(encouragement(for: completionFraction))
                .font(FMTheme.Typography.headline)
                .foregroundStyle(FMTheme.Colors.textPrimary)
        }
        .padding(FMTheme.Spacing.lg)
        .animation(FMTheme.Motion.gentle, value: completionFraction)
    }

    /// Time-of-day greeting. Nil when we don't know their name — better nothing than
    /// "Good morning, You".
    private var greeting: String? {
        guard let userName, !userName.isEmpty, userName != "You" else { return nil }
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<12: return "Good morning, \(userName)."
        case 12..<18: return "Afternoon, \(userName)."
        default: return "Evening, \(userName)."
        }
    }

    private func encouragement(for fraction: Double) -> String {
        switch fraction {
        case 0: return "Let's go."
        case ..<0.5: return "You're showing up."
        case ..<1: return "Halfway there."
        default: return "Perfect day unlocked 🎉"
        }
    }
}

#Preview {
    DayHeaderView(journey: Journey(startDate: Calendar.current.date(byAdding: .day, value: -16, to: .now) ?? .now), completionFraction: 0.67)
}
