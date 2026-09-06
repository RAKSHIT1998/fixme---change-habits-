import SwiftUI

/// Shown late in the day when habits are still open and a streak is live.
/// Loss aversion, stated plainly and without guilt — the streak is at stake, not their worth.
struct StreakAtRiskBanner: View {
    let streakDays: Int
    let remainingHabits: Int
    let onAct: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onAct) {
            HStack(spacing: FMTheme.Spacing.sm) {
                Text("🔥")
                    .font(.system(size: 28))
                    .scaleEffect(pulse ? 1.12 : 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streakDays)-day streak on the line")
                        .font(FMTheme.Typography.headline)
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    Text(remainingHabits == 1
                         ? "One habit left today. Finish it."
                         : "\(remainingHabits) habits left today.")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FMTheme.Colors.accent)
            }
            .padding(FMTheme.Spacing.md)
            .background(FMTheme.Colors.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous)
                    .stroke(FMTheme.Colors.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityLabel("\(streakDays) day streak at risk, \(remainingHabits) habits remaining today")
    }
}

/// Shown the morning after a missed day. Never says "you failed" — the entire point is
/// that users who miss a day come back instead of uninstalling.
struct ComebackCard: View {
    let streakAtStake: Int
    let freezesRemaining: Int
    let onUseFreeze: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
            Text("Yesterday didn't go as planned.")
                .font(FMTheme.Typography.headline)
                .foregroundStyle(FMTheme.Colors.textPrimary)

            Text("That's okay. The goal isn't perfection — it's getting back up. Today still counts.")
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if streakAtStake > 0 && freezesRemaining > 0 {
                Button(action: onUseFreeze) {
                    HStack(spacing: 6) {
                        Image(systemName: "snowflake")
                        Text("Use a streak freeze")
                            .font(FMTheme.Typography.subheadline)
                        Spacer(minLength: 0)
                        Text("\(freezesRemaining) left")
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                    }
                    .foregroundStyle(FMTheme.Colors.info)
                    .padding(FMTheme.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(FMTheme.Colors.info.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button(action: onContinue) {
                Text("GET BACK ON TRACK")
                    .font(FMTheme.Typography.subheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(FMTheme.Colors.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
    }
}

/// Celebratory moment when a streak crosses a meaningful number.
struct StreakMilestoneToast: View {
    let days: Int

    private var message: String {
        switch days {
        case 7: return "One week. That's not luck anymore."
        case 14: return "Two weeks. You're building something."
        case 30: return "You're becoming the person who does this."
        case 60: return "Two months. This is who you are now."
        case 90: return "Ninety days. Look what you did."
        default: return "\(days) days in a row."
        }
    }

    var body: some View {
        HStack(spacing: FMTheme.Spacing.sm) {
            Text("🔥").font(.system(size: 26))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(days) DAY STREAK")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(FMTheme.Colors.accent)
                Text(message)
                    .font(FMTheme.Typography.subheadline)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(FMTheme.Spacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
        .shadow(color: FMTheme.Shadow.elevated, radius: 16, y: 6)
    }
}

#Preview {
    VStack(spacing: 16) {
        StreakAtRiskBanner(streakDays: 12, remainingHabits: 2, onAct: {})
        ComebackCard(streakAtStake: 12, freezesRemaining: 1, onUseFreeze: {}, onContinue: {})
        StreakMilestoneToast(days: 7)
    }
    .padding()
}
