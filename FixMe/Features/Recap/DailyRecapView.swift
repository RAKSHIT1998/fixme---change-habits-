import SwiftUI

/// Celebratory end-of-day summary shown right after "Complete Day" — the emotional
/// payoff moment before the user closes the loop for the day.
struct DailyRecapView: View {
    let journey: Journey
    let dailyScore: Int
    let doneCount: Int
    let totalCount: Int
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var appear = false
    @State private var showShareSheet = false
    @State private var showJourneyCompletion = false
    @State private var showCompose = false
    @State private var showSendToFriend = false
    @State private var didPost = false

    private var dayNumber: Int { journey.dayNumber() }
    private var isPerfectDay: Bool { totalCount > 0 && doneCount == totalCount }
    private var isFinalDay: Bool { dayNumber >= journey.lengthInDays }

    var body: some View {
        NavigationStack {
            VStack(spacing: FMTheme.Spacing.lg) {
                Spacer()

                Text(isPerfectDay ? "🎉" : "✅")
                    .font(.system(size: 64))
                    .scaleEffect(appear ? 1 : 0.5)

                VStack(spacing: FMTheme.Spacing.xs) {
                    Text("Day \(dayNumber) complete.")
                        .font(FMTheme.Typography.display(30))
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    Text(closingLine)
                        .font(FMTheme.Typography.body)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    ProgressRing(progress: Double(dailyScore) / 100, size: 130)
                    VStack {
                        Text("\(dailyScore)").font(FMTheme.Typography.display(30))
                        Text("/ 100").font(FMTheme.Typography.footnote).foregroundStyle(FMTheme.Colors.textSecondary)
                    }
                }
                .padding(.vertical, FMTheme.Spacing.sm)

                Text("\(doneCount) of \(totalCount) habits · see you tomorrow.")
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textTertiary)

                Spacer()
                Spacer()

                if isFinalDay {
                    FMPrimaryButton(title: "Complete My 90 Days", icon: "trophy.fill") {
                        journey.isActive = false
                        journey.completedAt = .now
                        try? modelContext.save()
                        showJourneyCompletion = true
                    }
                } else {
                    FMPrimaryButton(title: "Share Progress", icon: "square.and.arrow.up") {
                        showShareSheet = true
                    }
                    // Posting to the wall is the only thing that puts anything in the
                    // Social tab, so it belongs right where the day is celebrated.
                    FMSecondaryButton(title: didPost ? "Posted to your wall ✓" : "Post to my wall") {
                        guard !didPost else { return }
                        showCompose = true
                    }
                    FMSecondaryButton(title: "Send to a friend") { showSendToFriend = true }
                }
                FMSecondaryButton(title: "Done") { onDismiss() }
            }
            .padding(FMTheme.Spacing.lg)
            .background(FMTheme.Colors.background)
            .onAppear {
                withAnimation(FMTheme.Motion.bouncy) { appear = true }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareTemplateView(journey: journey, dayNumber: dayNumber, completionPercent: dailyScore)
            }
            .sheet(isPresented: $showCompose) {
                ComposePostView(initialDraft: recapDraft) { _ in didPost = true }
            }
            .sheet(isPresented: $showSendToFriend) {
                ShareProgressView(journey: journey)
            }
            .fullScreenCover(isPresented: $showJourneyCompletion) {
                JourneyCompletionView(journey: journey) {
                    showJourneyCompletion = false
                    onDismiss()
                } onDismiss: {
                    showJourneyCompletion = false
                    onDismiss()
                }
            }
        }
    }

    /// Real numbers from the day being closed — nothing on a post is invented.
    private var recapDraft: SocialPostDraft {
        let habits = journey.habits.sorted { $0.sortOrder < $1.sortOrder }
        let completed = habits.filter { habit in
            habit.isQuit
                ? !habit.relapsed(on: .now)
                : (habit.completion(on: .now)?.state.isDone ?? false)
        }
        return SocialPostDraft(
            kind: isPerfectDay ? .milestone : .dayRecap,
            dayNumber: dayNumber,
            completionPercent: dailyScore,
            streak: habits.map { $0.currentStreak() }.max() ?? 0,
            habitNames: completed.map(\.name),
            milestoneTitle: isPerfectDay ? "Perfect day" : nil
        )
    }

    private var closingLine: String {
        if isPerfectDay { return "Perfect day unlocked. That's not luck anymore." }
        if dailyScore >= 50 { return "Small win. Big change." }
        return "Today still counts. Tomorrow is another rep."
    }
}

#Preview {
    DailyRecapView(journey: Journey(), dailyScore: 82, doneCount: 4, totalCount: 5, onDismiss: {})
}
