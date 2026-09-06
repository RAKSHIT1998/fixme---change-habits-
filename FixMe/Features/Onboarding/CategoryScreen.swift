import SwiftUI

struct CategoryScreen: View {
    var viewModel: OnboardingViewModel
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.lg) {
            OnboardingHeader(title: "What do you want to change?", subtitle: "Pick as many as you like.")

            ScrollView {
                LazyVGrid(columns: columns, spacing: FMTheme.Spacing.sm) {
                    ForEach(HabitCategory.allCases) { category in
                        CategoryCard(
                            category: category,
                            isSelected: viewModel.selectedCategories.contains(category)
                        ) {
                            viewModel.toggleCategory(category)
                        }
                    }
                }
            }

            FMPrimaryButton(title: "Continue", icon: "arrow.right", isEnabled: !viewModel.selectedCategories.isEmpty) {
                viewModel.advance()
            }
        }
        .padding(FMTheme.Spacing.lg)
    }
}

private struct CategoryCard: View {
    let category: HabitCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FMTheme.Spacing.xs) {
                Text(category.emoji).font(.system(size: 32))
                Text(category.title)
                    .font(FMTheme.Typography.subheadline)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FMTheme.Spacing.md)
            .background(isSelected ? FMTheme.Colors.forCategory(category).opacity(0.18) : FMTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? FMTheme.Colors.forCategory(category) : .clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .animation(FMTheme.Motion.snappy, value: isSelected)
    }
}

/// Shared header used by most onboarding screens.
struct OnboardingHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.xxs) {
            Text(title)
                .font(FMTheme.Typography.largeTitle)
                .foregroundStyle(FMTheme.Colors.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(FMTheme.Typography.body)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
            }
        }
        .padding(.top, FMTheme.Spacing.md)
    }
}

#Preview {
    CategoryScreen(viewModel: OnboardingViewModel())
}
