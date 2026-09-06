import SwiftUI
import SwiftData

struct JourneyView: View {
    @Query(filter: #Predicate<Journey> { $0.isActive }, sort: \Journey.startDate, order: .reverse)
    private var activeJourneys: [Journey]

    @State private var selectedDay: Int?
    @State private var showReel = false

    private var journey: Journey? { activeJourneys.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let journey {
                    VStack(spacing: FMTheme.Spacing.lg) {
                        JourneyStatsHeader(journey: journey)
                        JourneyPathView(journey: journey, selectedDay: $selectedDay)
                    }
                    .padding(.vertical, FMTheme.Spacing.md)
                } else {
                    ContentUnavailableView(
                        "One decision can change the next 90 days.",
                        systemImage: "map",
                        description: Text("Start a journey from Today to see your path here.")
                    )
                }
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Journey")
            .toolbar {
                if journey != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showReel = true } label: {
                            Label("Make a reel", systemImage: "film.stack")
                        }
                    }
                }
            }
            .sheet(isPresented: $showReel) {
                if let journey {
                    ProgressReelView(journey: journey, user: journey.owner)
                }
            }
            .sheet(item: Binding(
                get: { selectedDay.map { DayIdentifier(day: $0) } },
                set: { selectedDay = $0?.day }
            )) { identifier in
                if let journey {
                    DayDetailView(journey: journey, dayNumber: identifier.day)
                }
            }
        }
    }
}

private struct DayIdentifier: Identifiable { let day: Int; var id: Int { day } }

private struct JourneyStatsHeader: View {
    let journey: Journey

    var body: some View {
        HStack(spacing: FMTheme.Spacing.sm) {
            StatPill(value: "\(journey.dayNumber())", label: "Current day")
            StatPill(value: "\(journey.daysRemaining)", label: "Days left")
            StatPill(value: journey.commitmentLevel.title, label: "Commitment")
        }
        .padding(.horizontal, FMTheme.Spacing.md)
    }
}

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(FMTheme.Typography.headline).foregroundStyle(FMTheme.Colors.textPrimary)
            Text(label).font(FMTheme.Typography.footnote).foregroundStyle(FMTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FMTheme.Spacing.sm)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
    }
}

#Preview {
    JourneyView().modelContainer(PreviewData.container)
}
