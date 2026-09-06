import SwiftUI
import SwiftData

struct ExploreView: View {
    @Query(filter: #Predicate<Journey> { $0.isActive }, sort: \Journey.startDate, order: .reverse)
    private var activeJourneys: [Journey]
    @State private var selectedChallenge: HabitTemplateSeed?

    private var columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: FMTheme.Spacing.sm) {
                    ForEach(ChallengeCatalog.all) { challenge in
                        ChallengeCard(challenge: challenge) {
                            selectedChallenge = challenge
                        }
                    }
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Explore")
            .sheet(item: $selectedChallenge) { challenge in
                ChallengeDetailView(challenge: challenge, journey: activeJourneys.first)
            }
        }
    }
}

private struct ChallengeCard: View {
    let challenge: HabitTemplateSeed
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(challenge.category.emoji).font(.system(size: 26))
                Text(challenge.name)
                    .font(FMTheme.Typography.headline)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Text("\(challenge.duration) days · \(challenge.difficulty)")
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FMTheme.Spacing.md)
            .background(FMTheme.Colors.forCategory(challenge.category).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExploreView().modelContainer(PreviewData.container)
}
