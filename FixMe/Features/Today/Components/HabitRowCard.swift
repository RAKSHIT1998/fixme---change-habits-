import SwiftUI

/// The core habit interaction surface on Today — shows goal, live progress, verification
/// method, and current state, with a tap target sized for the habit's action.
struct HabitRowCard: View {
    let habit: Habit
    let state: HabitDayState
    let progress: Double
    let completion: HabitCompletion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FMTheme.Spacing.sm) {
                iconBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(FMTheme.Typography.headline)
                        .foregroundStyle(FMTheme.Colors.textPrimary)

                    HStack(spacing: 6) {
                        Text(progressText)
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                        if state.isDone {
                            VerificationBadge(type: habit.verificationType)
                        }
                    }

                    if !state.isDone && habit.goalTargetValue > 0 {
                        ProgressView(value: progress)
                            .tint(FMTheme.Colors.forCategory(habit.category))
                            .padding(.top, 2)
                    }
                }

                Spacer()

                statusIcon
            }
            .padding(FMTheme.Spacing.sm)
            .background(FMTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
            .opacity(state == .missed ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(state.isDone)
        .animation(FMTheme.Motion.snappy, value: state)
    }

    private var iconBadge: some View {
        Image(systemName: habit.iconSystemName)
            .font(.system(size: 20))
            .foregroundStyle(FMTheme.Colors.forCategory(habit.category))
            .frame(width: 44, height: 44)
            .background(FMTheme.Colors.forCategory(habit.category).opacity(0.15))
            .clipShape(Circle())
    }

    private var progressText: String {
        if state.isDone { return habit.goalDescription }
        if habit.verificationType == .healthKit || habit.verificationType == .hybrid, habit.goalTargetValue > 0 {
            return "\(Int(completion.progressValue).formatted()) / \(Int(habit.goalTargetValue).formatted()) \(habit.goalUnit)"
        }
        if habit.goalUnit == "ml" {
            return "\(Int(completion.progressValue))ml / \(Int(habit.goalTargetValue))ml"
        }
        if habit.goalUnit == "pages", completion.progressValue > 0 {
            return "\(Int(completion.progressValue)) / \(Int(habit.goalTargetValue)) pages"
        }
        return habit.goalDescription
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .verified:
            Image(systemName: "checkmark.seal.fill").foregroundStyle(FMTheme.Colors.accent)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(FMTheme.Colors.success)
        case .waitingForProof:
            ProgressView()
        case .missed:
            Image(systemName: "arrow.uturn.forward.circle").foregroundStyle(FMTheme.Colors.textTertiary)
        case .notStarted, .inProgress:
            if habit.verificationType == .photoAI || habit.verificationType == .hybrid {
                ProveItPill()
            } else {
                Image(systemName: "chevron.right").foregroundStyle(FMTheme.Colors.textTertiary)
            }
        }
    }
}

private struct ProveItPill: View {
    var body: some View {
        Text("PROVE IT")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(FMTheme.Colors.accent)
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        HabitRowCard(
            habit: HabitCatalog.all[0].makeHabit(),
            state: .notStarted,
            progress: 0,
            completion: HabitCompletion(),
            action: {}
        )
        HabitRowCard(
            habit: HabitCatalog.all[1].makeHabit(),
            state: .inProgress,
            progress: 0.74,
            completion: HabitCompletion(progressValue: 7482),
            action: {}
        )
        HabitRowCard(
            habit: HabitCatalog.all[0].makeHabit(),
            state: .verified,
            progress: 1,
            completion: HabitCompletion(),
            action: {}
        )
    }
    .padding()
}
