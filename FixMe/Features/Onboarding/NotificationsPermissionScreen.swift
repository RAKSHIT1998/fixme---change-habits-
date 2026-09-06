import SwiftUI

struct NotificationsPermissionScreen: View {
    var viewModel: OnboardingViewModel
    @Environment(\.services) private var services

    var body: some View {
        PermissionScreenLayout(
            emoji: "🔔",
            title: "Stay on track",
            message: "Your future self needs a little nudge.",
            primaryTitle: "Allow notifications"
        ) {
            Task {
                viewModel.notificationsGranted = await services.notifications.requestAuthorization()
                viewModel.advance()
            }
        } skip: {
            viewModel.advance()
        }
    }
}

struct HealthPermissionScreen: View {
    var viewModel: OnboardingViewModel
    @Environment(\.services) private var services

    var body: some View {
        PermissionScreenLayout(
            emoji: "❤️",
            title: "Let Health do the work",
            message: "Let Fix Me automatically verify steps, workouts and sleep when possible.",
            primaryTitle: "Connect Apple Health"
        ) {
            Task {
                viewModel.healthGranted = await services.healthKit.requestAuthorization()
                viewModel.advance()
            }
        } skip: {
            viewModel.advance()
        }
    }
}

/// Shared layout for the two permission-request onboarding screens.
private struct PermissionScreenLayout: View {
    let emoji: String
    let title: String
    let message: String
    let primaryTitle: String
    let primaryAction: () -> Void
    let skip: () -> Void

    var body: some View {
        VStack(spacing: FMTheme.Spacing.lg) {
            Spacer()
            Text(emoji).font(.system(size: 56))
            VStack(spacing: FMTheme.Spacing.xs) {
                Text(title).font(FMTheme.Typography.title).multilineTextAlignment(.center)
                Text(message)
                    .font(FMTheme.Typography.body)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Spacer()
            FMPrimaryButton(title: primaryTitle, action: primaryAction)
            FMSecondaryButton(title: "Not now", action: skip)
        }
        .padding(FMTheme.Spacing.lg)
    }
}

#Preview {
    NotificationsPermissionScreen(viewModel: OnboardingViewModel())
}
