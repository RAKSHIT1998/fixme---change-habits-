import SwiftUI

struct WelcomeScreen: View {
    var viewModel: OnboardingViewModel
    @State private var appear = false

    var body: some View {
        VStack(spacing: FMTheme.Spacing.lg) {
            Spacer()

            Text("🛠️")
                .font(.system(size: 64))
                .scaleEffect(appear ? 1 : 0.6)
                .opacity(appear ? 1 : 0)

            VStack(spacing: FMTheme.Spacing.sm) {
                Text("Ready to fix your days?")
                    .font(FMTheme.Typography.display(36))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(FMTheme.Colors.textPrimary)

                Text("Small habits. 90 days. A different you.")
                    .font(FMTheme.Typography.body)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 12)

            Spacer()
            Spacer()

            FMPrimaryButton(title: "Let's do this", icon: "arrow.right") {
                viewModel.advance()
            }
        }
        .padding(FMTheme.Spacing.lg)
        .padding(.bottom, FMTheme.Spacing.lg)
        .onAppear {
            withAnimation(FMTheme.Motion.bouncy.delay(0.1)) { appear = true }
        }
    }
}

#Preview {
    WelcomeScreen(viewModel: OnboardingViewModel())
}
