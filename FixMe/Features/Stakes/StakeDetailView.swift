import SwiftUI
import SwiftData

/// The challenge in full: where it stands, the terms that were agreed, and the only two
/// ways out of it.
struct StakeDetailView: View {
    let challenge: StakeChallenge
    let habits: [Habit]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showGiveUpConfirm = false

    private var status: StakeStatus {
        StakeRules.status(for: challenge, habits: habits)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FMTheme.Spacing.lg) {
                    header
                    StakeCard(challenge: challenge, status: status) {}
                    terms
                    if challenge.isActive { giveUp }
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("StakeChallenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
            .confirmationDialog(
                "Giving up ends the challenge exactly as missing a day would. \(challenge.formattedStake) is forfeit.",
                isPresented: $showGiveUpConfirm,
                titleVisibility: .visible
            ) {
                Button("Give up the challenge", role: .destructive) {
                    let day = StakeRules.dayNumber(for: challenge, on: .now)
                    StakeService(modelContext: modelContext).giveUp(challenge, onDay: day)
                    dismiss()
                }
                Button("Keep going", role: .cancel) {}
            }
        }
    }

    private var header: some View {
        VStack(spacing: FMTheme.Spacing.xs) {
            Text(challenge.formattedStake)
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(FMTheme.Colors.accent)
            Text(challenge.stakeHolder.isEmpty
                 ? "staked on \(challenge.lengthInDays) days"
                 : "staked on \(challenge.lengthInDays) days — \(challenge.stakeHolder) collects if you miss")
                .font(FMTheme.Typography.subheadline)
                .foregroundStyle(FMTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            if let referee = challenge.refereeName {
                Text("Referee: \(referee)")
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textTertiary)
            }
        }
    }

    private var terms: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
            Text("What you agreed")
                .font(FMTheme.Typography.headline)

            term("Every habit, every day, for \(challenge.lengthInDays) days.")
            term("One missed day ends it. Streak freezes and repair don't apply.")
            term("Quit habits count as kept unless you log a relapse.")
            term("Fix Me never held your money. Settling up is between you and \(challenge.stakeHolder.isEmpty ? "whoever's collecting" : challenge.stakeHolder).")

            Text("Agreed \(challenge.acceptedTermsAt.formatted(date: .abbreviated, time: .shortened))")
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textTertiary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
    }

    private func term(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FMTheme.Colors.accent)
                .padding(.top, 4)
            Text(text)
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textSecondary)
        }
    }

    private var giveUp: some View {
        Button("Give up") { showGiveUpConfirm = true }
            .font(FMTheme.Typography.caption)
            .foregroundStyle(FMTheme.Colors.danger)
    }
}

#Preview {
    StakeDetailView(challenge: StakeChallenge(stakeHolder: "Sam"), habits: [])
        .modelContainer(PreviewData.container)
}
