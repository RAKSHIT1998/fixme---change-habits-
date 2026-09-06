import SwiftUI

struct HabitPickerScreen: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.lg) {
            OnboardingHeader(title: "Pick your habits", subtitle: "You can add or change these anytime.")

            ScrollView {
                VStack(spacing: FMTheme.Spacing.xs) {
                    ForEach(viewModel.suggestedHabits) { blueprint in
                        HabitPickRow(
                            blueprint: blueprint,
                            isSelected: viewModel.selectedHabitNames.contains(blueprint.name)
                        ) {
                            viewModel.toggleHabit(blueprint)
                        }
                    }
                }
            }

            FMPrimaryButton(
                title: viewModel.selectedHabitNames.isEmpty ? "Continue" : "Continue with \(viewModel.selectedHabitNames.count)",
                icon: "arrow.right"
            ) {
                viewModel.advance()
            }
        }
        .padding(FMTheme.Spacing.lg)
    }
}

private struct HabitPickRow: View {
    let blueprint: HabitBlueprint
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FMTheme.Spacing.sm) {
                Image(systemName: blueprint.iconSystemName)
                    .font(.system(size: 18))
                    .foregroundStyle(FMTheme.Colors.forCategory(blueprint.category))
                    .frame(width: 36, height: 36)
                    .background(FMTheme.Colors.forCategory(blueprint.category).opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(blueprint.name).font(FMTheme.Typography.headline).foregroundStyle(FMTheme.Colors.textPrimary)
                    Text(blueprint.goalDescription).font(FMTheme.Typography.footnote).foregroundStyle(FMTheme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? FMTheme.Colors.accent : FMTheme.Colors.textTertiary)
            }
            .padding(FMTheme.Spacing.sm)
            .background(FMTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HabitPickerScreen(viewModel: OnboardingViewModel())
}
