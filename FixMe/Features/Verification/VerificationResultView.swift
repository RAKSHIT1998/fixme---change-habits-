import SwiftUI

/// Shows the hedged AI verification outcome — never claims impossible certainty.
struct VerificationResultView: View {
    let outcome: VerificationOutcome
    let onDone: () -> Void
    let onRetake: () -> Void

    var body: some View {
        VStack(spacing: FMTheme.Spacing.lg) {
            Spacer()

            statusIcon
                .font(.system(size: 56))
                .foregroundStyle(statusColor)

            VStack(spacing: FMTheme.Spacing.xs) {
                Text(statusTitle)
                    .font(FMTheme.Typography.title)
                    .foregroundStyle(.white)
                Text(outcome.headline)
                    .font(FMTheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                Text(outcome.explanation)
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .padding(.horizontal, FMTheme.Spacing.lg)

            if outcome.status == .verified || outcome.status == .needsReview {
                confidenceMeter
            }

            Spacer()
            Spacer()

            if outcome.status == .rejected || outcome.status == .unableToVerify {
                VStack(spacing: FMTheme.Spacing.sm) {
                    FMPrimaryButton(title: "Try Again", icon: "arrow.clockwise") { onRetake() }
                    FMSecondaryButton(title: "Mark manually") { onDone() }
                }
                .padding(.horizontal, FMTheme.Spacing.lg)
                .padding(.bottom, FMTheme.Spacing.xl)
            } else {
                FMPrimaryButton(title: "Done", icon: "checkmark") { onDone() }
                    .padding(.horizontal, FMTheme.Spacing.lg)
                    .padding(.bottom, FMTheme.Spacing.xl)
            }
        }
    }

    private var statusIcon: Image {
        switch outcome.status {
        case .verified: return Image(systemName: "checkmark.seal.fill")
        case .needsReview: return Image(systemName: "questionmark.circle.fill")
        case .rejected: return Image(systemName: "xmark.circle.fill")
        case .unableToVerify: return Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private var statusColor: Color {
        switch outcome.status {
        case .verified: return FMTheme.Colors.accent
        case .needsReview: return FMTheme.Colors.warning
        case .rejected: return FMTheme.Colors.danger
        case .unableToVerify: return FMTheme.Colors.textTertiary
        }
    }

    private var statusTitle: String {
        switch outcome.status {
        case .verified: return "VERIFIED ✓"
        case .needsReview: return "Looks close"
        case .rejected: return "Not quite"
        case .unableToVerify: return "Unable to verify"
        }
    }

    private var confidenceMeter: some View {
        VStack(spacing: 4) {
            Text("Evidence: \(Int(outcome.confidence * 100))%")
                .font(FMTheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.7))
            ProgressView(value: outcome.confidence)
                .tint(statusColor)
                .frame(width: 160)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VerificationResultView(
            outcome: VerificationOutcome(status: .verified, confidence: 0.92, headline: "Looks like you're awake 👀", explanation: "Strong evidence of an alert, awake face.", timestamp: .now),
            onDone: {},
            onRetake: {}
        )
    }
}
