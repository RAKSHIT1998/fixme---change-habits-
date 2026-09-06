import SwiftUI

struct FinalCommitScreen: View {
    var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    @State private var appear = false
    @State private var isStarting = false

    var body: some View {
        VStack(spacing: FMTheme.Spacing.lg) {
            Spacer()

            Text("🚀")
                .font(.system(size: 64))
                .scaleEffect(appear ? 1 : 0.5)

            Text(viewModel.startToday ? "Day 1 starts now." : "Day 1 starts tomorrow.")
                .font(FMTheme.Typography.display(32))
                .multilineTextAlignment(.center)
                .foregroundStyle(FMTheme.Colors.textPrimary)

            Text("\(viewModel.selectedBlueprints.isEmpty ? 4 : viewModel.selectedBlueprints.count) habits. 90 days. No perfection required — just showing up.")
                .font(FMTheme.Typography.body)
                .foregroundStyle(FMTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: FMTheme.Spacing.xxs) {
                Text("What should we call you?")
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
                TextField("Your name", text: Bindable(viewModel).name)
                    .textContentType(.givenName)
                    .padding(FMTheme.Spacing.sm)
                    .background(FMTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                Text("Used for your morning greeting, and it's the name friends see if you pair with anyone.")
                    .font(.system(size: 11))
                    .foregroundStyle(FMTheme.Colors.textTertiary)
            }

            Toggle("Start today", isOn: Bindable(viewModel).startToday)
                .padding(FMTheme.Spacing.sm)
                .background(FMTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                .tint(FMTheme.Colors.accent)

            Spacer()
            Spacer()

            FMPrimaryButton(title: "START MY 90 DAYS", icon: "flag.checkered", isLoading: isStarting) {
                isStarting = true
                Haptics.notify(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onComplete()
                }
            }
        }
        .padding(FMTheme.Spacing.lg)
        .onAppear {
            withAnimation(FMTheme.Motion.bouncy) { appear = true }
        }
    }
}

#Preview {
    FinalCommitScreen(viewModel: OnboardingViewModel(), onComplete: {})
}
