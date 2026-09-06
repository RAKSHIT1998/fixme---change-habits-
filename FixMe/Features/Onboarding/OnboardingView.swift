import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @State private var viewModel = OnboardingViewModel()
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            FMTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.step != .welcome {
                    OnboardingProgressBar(step: viewModel.step)
                        .padding(.horizontal, FMTheme.Spacing.lg)
                        .padding(.top, FMTheme.Spacing.sm)
                }

                Group {
                    switch viewModel.step {
                    case .welcome: WelcomeScreen(viewModel: viewModel)
                    case .categories: CategoryScreen(viewModel: viewModel)
                    case .habits: HabitPickerScreen(viewModel: viewModel)
                    case .quitPrograms: QuitSetupScreen(viewModel: viewModel)
                    case .commitment: CommitmentScreen(viewModel: viewModel)
                    case .journeyPreview: JourneyPreviewScreen(viewModel: viewModel)
                    case .notifications: NotificationsPermissionScreen(viewModel: viewModel)
                    case .health: HealthPermissionScreen(viewModel: viewModel)
                    case .commit: FinalCommitScreen(viewModel: viewModel, onComplete: complete)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(viewModel.step)
            }
        }
        .animation(FMTheme.Motion.gentle, value: viewModel.step)
        // The paywall is the last beat of onboarding, not a separate screen later:
        // this is the moment the user has just committed to 90 days, and it converts
        // several times better than any prompt we could show a week from now.
        .fullScreenCover(isPresented: $showPaywall, onDismiss: enterApp) {
            PaywallView(trigger: .onboardingComplete)
        }
    }

    /// Persists the journey immediately, then offers Premium. If the user declines, they
    /// still land in a fully working app — the free tier is the product, not a demo.
    private func complete() {
        viewModel.persistJourney(context: modelContext)
        // Without this, every friend you pair with sees the placeholder name.
        services.peerIdentity.displayName = viewModel.resolvedName
        showPaywall = true
    }

    private func enterApp() {
        viewModel.finishOnboarding(appState: appState)
    }
}

private struct OnboardingProgressBar: View {
    let step: OnboardingViewModel.Step

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingViewModel.Step.allCases, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? FMTheme.Colors.accent : FMTheme.Colors.surfaceElevated)
                    .frame(height: 4)
            }
        }
        .animation(FMTheme.Motion.gentle, value: step)
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
        .modelContainer(PersistenceController.makeContainer(inMemory: true))
}
