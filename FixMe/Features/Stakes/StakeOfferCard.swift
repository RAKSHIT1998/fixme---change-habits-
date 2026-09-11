import SwiftUI

/// When to suggest staking something.
///
/// The challenge was reachable only from Settings, which is where features go to be never
/// found — the same mistake the reel had before `ReelPrompt`. But this one asks someone to
/// put money on the line, so it has to be offered at a moment when the answer is plausibly
/// yes and never feel like a shakedown.
///
/// So: only once there's a real run to protect, only for someone with habits actually
/// going, and it goes away for a fortnight the moment it's waved off. Asking someone on
/// day 2 to bet on 90 days is asking a stranger for money.
enum StakeInvitation {
    static let earliestDay = 10
    static let minimumStreak = 5
    static let daysBetweenAsks = 14

    static func shouldOffer(
        dayNumber: Int,
        habitCount: Int,
        longestStreak: Int,
        dismissedOnDay: Int
    ) -> Bool {
        guard habitCount > 0 else { return false }
        guard dayNumber >= earliestDay else { return false }
        // A streak is the evidence that they'd probably win. Offering a stake to someone
        // who is already missing days is selling them a loss.
        guard longestStreak >= minimumStreak else { return false }
        guard dayNumber - dismissedOnDay >= daysBetweenAsks || dismissedOnDay == 0 else { return false }
        return true
    }
}

struct StakeOfferCard: View {
    let onStart: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
            HStack(spacing: FMTheme.Spacing.sm) {
                Text("🔒").font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Make it cost something.")
                        .font(FMTheme.Typography.headline)
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    Text("Stake money on finishing your 90 days. Miss one day and it's gone — which is exactly why people finish.")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)

                    // Stated here, not only on the setup screen. This card is the first
                    // mention of money anywhere in the app, and App Review may well read
                    // it without tapping through — "stake money... it's gone" on its own
                    // reads like the app collects payment outside IAP, or runs a wager.
                    Text("Fix Me never takes or holds the money. You settle it yourself.")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textTertiary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: FMTheme.Spacing.sm) {
                Button(action: onStart) {
                    Text("Set a stake")
                        .font(FMTheme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, FMTheme.Spacing.md)
                        .padding(.vertical, FMTheme.Spacing.xs)
                        .background(FMTheme.Colors.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button("Not for me", action: onDismiss)
                    .font(FMTheme.Typography.caption)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
            }
        }
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
    }
}

#Preview {
    StakeOfferCard(onStart: {}, onDismiss: {}).padding()
}
