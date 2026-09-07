import SwiftUI

/// The challenge, on Today. Three states, and the at-risk one is the whole point of it
/// being on this screen at all.
struct StakeCard: View {
    let challenge: StakeChallenge
    let status: StakeStatus
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                HStack(spacing: FMTheme.Spacing.xs) {
                    Text(emoji).font(.system(size: 22))
                    Text(headline)
                        .font(FMTheme.Typography.headline)
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    Spacer(minLength: 0)
                    Text(challenge.formattedStake)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                }

                Text(detail)
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)

                if let progress {
                    ProgressView(value: progress)
                        .tint(accent)
                }
            }
            .padding(FMTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous)
                    .stroke(accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var accent: Color {
        switch status {
        case .atRisk: return FMTheme.Colors.danger
        case .lost: return FMTheme.Colors.textTertiary
        case .won: return FMTheme.Colors.success
        case .safe: return FMTheme.Colors.accent
        }
    }

    private var emoji: String {
        switch status {
        case .atRisk: return "⚠️"
        case .lost: return "💸"
        case .won: return "🏆"
        case .safe: return "🔒"
        }
    }

    private var headline: String {
        switch status {
        case let .safe(day, _): return "Day \(day) locked in"
        case let .atRisk(day, _, _): return "Day \(day) isn't done"
        case let .lost(day): return "StakeChallenge lost on day \(day)"
        case .won: return "StakeChallenge complete"
        }
    }

    private var detail: String {
        switch status {
        case let .safe(_, remaining):
            return "\(remaining) day\(remaining == 1 ? "" : "s") to go. Nothing at risk today."
        case let .atRisk(_, _, open):
            return "\(open) habit\(open == 1 ? "" : "s") still open. Miss today and \(challenge.formattedStake) is gone."
        case .lost:
            return challenge.stakeHolder.isEmpty
                ? "Your 90 days keep going. You can start a new challenge any time."
                : "\(challenge.formattedStake) goes to \(challenge.stakeHolder)."
        case .won:
            return "\(challenge.lengthInDays) days, not one missed. Your \(challenge.formattedStake) is yours."
        }
    }

    private var progress: Double? {
        switch status {
        case let .safe(day, _), let .atRisk(day, _, _):
            return Double(day) / Double(challenge.lengthInDays)
        case .won: return 1
        case .lost: return nil
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StakeCard(challenge: StakeChallenge(stakeHolder: "Sam"),
                      status: .safe(day: 34, daysRemaining: 56)) {}
        StakeCard(challenge: StakeChallenge(stakeHolder: "Sam"),
                      status: .atRisk(day: 34, daysRemaining: 56, openHabits: 2)) {}
        StakeCard(challenge: StakeChallenge(stakeHolder: "Sam"), status: .lost(onDay: 34)) {}
        StakeCard(challenge: StakeChallenge(stakeHolder: "Sam"), status: .won) {}
    }
    .padding()
}
