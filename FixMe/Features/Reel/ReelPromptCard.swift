import SwiftUI

/// The milestone-day nudge to make a reel. Styled alongside the other Today moment cards
/// so it reads as part of the same family, not an ad.
struct ReelPromptCard: View {
    let milestone: Milestone
    let totalDays: Int
    let onMake: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
            HStack(spacing: FMTheme.Spacing.sm) {
                Text(milestone.emoji).font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text(ReelPrompt.headline(for: milestone, totalDays: totalDays))
                        .font(FMTheme.Typography.headline)
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    Text(ReelPrompt.detail(for: milestone))
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: FMTheme.Spacing.sm) {
                Button(action: onMake) {
                    HStack(spacing: 6) {
                        Image(systemName: "film.stack")
                        Text("Make my reel")
                    }
                    .font(FMTheme.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, FMTheme.Spacing.md)
                    .padding(.vertical, FMTheme.Spacing.xs)
                    .background(FMTheme.Colors.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button("Not now", action: onDismiss)
                    .font(FMTheme.Typography.caption)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
            }
        }
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous)
                .stroke(FMTheme.Colors.accent.opacity(0.30), lineWidth: 1)
        )
    }
}

#Preview {
    VStack {
        ReelPromptCard(milestone: Milestone(day: 30, title: "One Month", emoji: "🔥"),
                       totalDays: 90, onMake: {}, onDismiss: {})
        ReelPromptCard(milestone: Milestone(day: 90, title: "TRANSFORMED", emoji: "🏆"),
                       totalDays: 90, onMake: {}, onDismiss: {})
    }
    .padding()
}
