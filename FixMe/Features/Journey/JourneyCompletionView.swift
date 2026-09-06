import SwiftUI
import SwiftData

/// The Day 90 celebration — the emotional peak of a completed transformation.
struct JourneyCompletionView: View {
    let journey: Journey
    let onStartNewJourney: () -> Void
    let onDismiss: () -> Void

    @State private var appear = false
    @State private var showShare = false

    private var totalCompleted: Int {
        journey.habits.reduce(0) { $0 + $1.completions.filter { $0.state.isDone }.count }
    }
    private var bestStreak: Int { journey.habits.map { $0.currentStreak() }.max() ?? 0 }
    private var totalSteps: Double {
        journey.habits.filter { $0.goalUnit == "steps" }
            .reduce(0) { $0 + $1.completions.reduce(0) { $0 + $1.progressValue } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FMTheme.Spacing.lg) {
                    Spacer(minLength: FMTheme.Spacing.xl)

                    Text("🏆").font(.system(size: 72)).scaleEffect(appear ? 1 : 0.4)

                    VStack(spacing: 4) {
                        Text("YOU DID IT.").font(FMTheme.Typography.display(38)).foregroundStyle(FMTheme.Colors.textPrimary)
                        Text("90 DAYS.").font(FMTheme.Typography.display(38)).foregroundStyle(FMTheme.Colors.accent)
                    }
                    .multilineTextAlignment(.center)

                    VStack(spacing: FMTheme.Spacing.sm) {
                        HStack(spacing: FMTheme.Spacing.sm) {
                            RecapStat(value: "\(journey.lengthInDays)", label: "Days completed")
                            RecapStat(value: "\(totalCompleted)", label: "Habits completed")
                        }
                        HStack(spacing: FMTheme.Spacing.sm) {
                            RecapStat(value: "\(bestStreak)", label: "Best streak")
                            RecapStat(value: totalSteps > 0 ? "\(Int(totalSteps).formatted())" : "—", label: "Total steps")
                        }
                    }

                    Text("Look how far you've come.")
                        .font(FMTheme.Typography.title2)
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                        .padding(.top, FMTheme.Spacing.sm)

                    VStack(spacing: FMTheme.Spacing.sm) {
                        FMPrimaryButton(title: "Share My 90-Day Journey", icon: "square.and.arrow.up") {
                            showShare = true
                        }
                        FMSecondaryButton(title: "What do you want to fix next?") {
                            onStartNewJourney()
                        }
                    }
                    .padding(.top, FMTheme.Spacing.md)
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { onDismiss() } }
            }
            .onAppear {
                withAnimation(FMTheme.Motion.bouncy) { appear = true }
            }
            .sheet(isPresented: $showShare) {
                ShareTemplateView(journey: journey, dayNumber: journey.lengthInDays, completionPercent: 100)
            }
        }
    }
}

private struct RecapStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(FMTheme.Typography.title).foregroundStyle(FMTheme.Colors.textPrimary)
            Text(label).font(FMTheme.Typography.footnote).foregroundStyle(FMTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FMTheme.Spacing.md)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
    }
}

#Preview {
    JourneyCompletionView(journey: Journey(), onStartNewJourney: {}, onDismiss: {})
        .modelContainer(PreviewData.container)
}
