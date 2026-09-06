import SwiftUI

struct JourneyPreviewScreen: View {
    var viewModel: OnboardingViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 10)

    var body: some View {
        VStack(spacing: FMTheme.Spacing.lg) {
            OnboardingHeader(title: "Your 90-day journey starts...")

            VStack(spacing: 4) {
                Text(viewModel.journeyStartDate.formattedShort())
                    .font(FMTheme.Typography.title)
                Image(systemName: "arrow.down")
                    .foregroundStyle(FMTheme.Colors.textTertiary)
                Text(viewModel.journeyEndDate.formattedShort())
                    .font(FMTheme.Typography.title)
            }
            .foregroundStyle(FMTheme.Colors.textPrimary)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<90, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(FMTheme.Colors.accent.opacity(0.15 + 0.65 * (Double(day) / 90)))
                        .frame(height: 14)
                }
            }
            .padding(FMTheme.Spacing.md)
            .background(FMTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))

            Text("90 days. \(viewModel.selectedBlueprints.isEmpty ? 4 : viewModel.selectedBlueprints.count) habits. One version of you worth becoming.")
                .font(FMTheme.Typography.body)
                .foregroundStyle(FMTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            FMPrimaryButton(title: "Continue", icon: "arrow.right") {
                viewModel.advance()
            }
        }
        .padding(FMTheme.Spacing.lg)
    }
}

#Preview {
    JourneyPreviewScreen(viewModel: OnboardingViewModel())
}
