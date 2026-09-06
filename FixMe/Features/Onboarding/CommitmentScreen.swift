import SwiftUI

struct CommitmentScreen: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: FMTheme.Spacing.xl) {
            OnboardingHeader(title: "How serious are you?", subtitle: "This just tunes your suggested difficulty — never a punishment.")

            Spacer()

            VStack(spacing: FMTheme.Spacing.md) {
                Text(viewModel.commitmentLevel.title)
                    .font(FMTheme.Typography.display(32))
                    .foregroundStyle(FMTheme.Colors.accent)
                    .contentTransition(.numericText())
                    .animation(FMTheme.Motion.snappy, value: viewModel.commitmentLevel)

                Slider(value: Bindable(viewModel).commitmentSlider, in: 0...1)
                    .tint(FMTheme.Colors.accent)

                HStack {
                    Text("Casual").font(FMTheme.Typography.caption).foregroundStyle(FMTheme.Colors.textTertiary)
                    Spacer()
                    Text("LOCKED IN").font(FMTheme.Typography.caption).foregroundStyle(FMTheme.Colors.textTertiary)
                }
            }
            .padding(FMTheme.Spacing.lg)
            .background(FMTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))

            Spacer()
            Spacer()

            FMPrimaryButton(title: "Continue", icon: "arrow.right") {
                viewModel.advance()
            }
        }
        .padding(FMTheme.Spacing.lg)
    }
}

#Preview {
    CommitmentScreen(viewModel: OnboardingViewModel())
}
