import SwiftUI
import SwiftData

struct ChallengeDetailView: View {
    let challenge: HabitTemplateSeed
    let journey: Journey?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var added = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FMTheme.Spacing.lg) {
                    Text(challenge.category.emoji).font(.system(size: 48))
                    Text(challenge.name).font(FMTheme.Typography.largeTitle)
                    Text(challenge.description)
                        .font(FMTheme.Typography.body)
                        .foregroundStyle(FMTheme.Colors.textSecondary)

                    HStack(spacing: FMTheme.Spacing.sm) {
                        InfoChip(text: "\(challenge.duration) days")
                        InfoChip(text: challenge.difficulty)
                        InfoChip(text: challenge.category.title)
                    }

                    VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                        Text("Habits included").font(FMTheme.Typography.headline)
                        ForEach(challenge.blueprints) { bp in
                            HStack(spacing: FMTheme.Spacing.sm) {
                                Image(systemName: bp.iconSystemName).foregroundStyle(FMTheme.Colors.forCategory(bp.category))
                                Text(bp.name).foregroundStyle(FMTheme.Colors.textPrimary)
                                Spacer()
                                Text(bp.goalDescription).font(FMTheme.Typography.footnote).foregroundStyle(FMTheme.Colors.textSecondary)
                            }
                            .padding(FMTheme.Spacing.sm)
                            .background(FMTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                        }
                    }

                    FMPrimaryButton(title: added ? "Added ✓" : "Add to my 90 days", isEnabled: !added && journey != nil) {
                        addToJourney()
                    }
                    if journey == nil {
                        Text("Start a journey first from Today.").font(FMTheme.Typography.footnote).foregroundStyle(FMTheme.Colors.textTertiary)
                    }
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
        }
    }

    private func addToJourney() {
        guard let journey else { return }
        for (index, bp) in challenge.blueprints.enumerated() {
            let habit = bp.makeHabit(sortOrder: journey.habits.count + index)
            habit.journey = journey
            modelContext.insert(habit)
        }
        try? modelContext.save()
        Haptics.notify(.success)
        withAnimation { added = true }
    }
}

private struct InfoChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(FMTheme.Typography.footnote)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(FMTheme.Colors.surface)
            .clipShape(Capsule())
    }
}

#Preview {
    ChallengeDetailView(challenge: ChallengeCatalog.all[0], journey: Journey())
}
