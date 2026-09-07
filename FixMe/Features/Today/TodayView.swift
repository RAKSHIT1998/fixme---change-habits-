import SwiftUI
import SwiftData
import StoreKit

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.requestReview) private var requestReview
    @Query(filter: #Predicate<Journey> { $0.isActive }, sort: \Journey.startDate, order: .reverse)
    private var activeJourneys: [Journey]
    @Query private var users: [User]

    @State private var viewModel: TodayViewModel?
    @State private var verifyingHabit: Habit?
    @State private var waterHabitForLogging: Habit?
    @State private var habitForDetail: Habit?
    @State private var quitHabitForDetail: Habit?
    @State private var showCreateHabit = false
    @State private var showNightReview = false
    @State private var paywallTrigger: PaywallTrigger?
    @State private var dismissedComeback = false
    @State private var showReel = false
    /// Day number and score from the review just finished, read once the sheet is gone.
    @State private var completedDay: (day: Int, score: Int)?
    @State private var showStakeSetup = false
    @State private var showStakeDetail = false
    /// Day the challenge offer was last waved away, so it asks again later rather than
    /// every single morning.
    @AppStorage("stakeOfferDismissedDay") private var stakeOfferDismissedDay = 0
    @Query(sort: \StakeChallenge.startDate, order: .reverse) private var challenges: [StakeChallenge]
    /// Which day number the milestone reel prompt was last offered for, so it appears
    /// once per milestone rather than every launch.
    @AppStorage("reelPromptedDay") private var reelPromptedDay = 0

    private var journey: Journey? { activeJourneys.first }
    private var user: User? { users.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let journey, let viewModel {
                    content(journey: journey, viewModel: viewModel)
                } else {
                    TodayEmptyState { startNewJourney() }
                }
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        requestAddHabit()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = TodayViewModel(modelContext: modelContext, services: services)
                }
                await services.subscriptions.loadProducts()
                await services.healthKit.refreshTodayMetrics()
                syncHealthKit(journey: journey)
                refreshStake()
                scheduleSmartReminders()
                // Without this the widget has nothing to show until the first habit is
                // completed, which is what made a Day 1 journey render as Day 17.
                WidgetSnapshotPublisher.publish(from: modelContext)
            }
            .sheet(item: $verifyingHabit) { habit in
                CameraVerificationView(habit: habit) { outcome, fileName in
                    // A verification we couldn't complete shouldn't cost the user one of
                    // their free checks — charging for our own failure invites refunds.
                    if outcome.status == .verified || outcome.status == .needsReview {
                        services.premium.recordAIVerificationUse()
                    }
                    viewModel?.applyVerification(habit, outcome: outcome, imageFileName: fileName)
                    stakeDidChange()
                }
            }
            .sheet(item: $waterHabitForLogging) { habit in
                QuickLogSheet(habit: habit) { amount in
                    viewModel?.addProgress(habit, delta: amount)
                    stakeDidChange()
                }
                .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showCreateHabit) {
                if let journey {
                    CreateHabitView(journey: journey)
                }
            }
            .sheet(isPresented: $showReel) {
                if let journey { ProgressReelView(journey: journey, user: user) }
            }
            .sheet(isPresented: $showStakeSetup) {
                if let journey { StakeSetupView(journey: journey) }
            }
            .sheet(isPresented: $showStakeDetail) {
                if let challenge = activeStake ?? challenges.first {
                    StakeDetailView(challenge: challenge, habits: journey?.habits ?? [])
                }
            }
            // Asked after the sheet is gone, not over the top of the recap: the rating
            // prompt should land on a finished, satisfying moment rather than interrupt
            // the celebration it's reacting to.
            .sheet(isPresented: $showNightReview, onDismiss: askForReviewIfEarned) {
                if let journey {
                    NightReviewView(journey: journey) { day, score in
                        completedDay = (day, score)
                    }
                }
            }
            .sheet(item: $paywallTrigger) { trigger in
                PaywallView(trigger: trigger)
            }
            .navigationDestination(item: $habitForDetail) { habit in
                HabitDetailView(habit: habit)
            }
            .navigationDestination(item: $quitHabitForDetail) { habit in
                QuitTrackerView(habit: habit)
            }
        }
    }

    @ViewBuilder
    private func content(journey: Journey, viewModel: TodayViewModel) -> some View {
        let allHabits = journey.habits.sorted { $0.sortOrder < $1.sortOrder }
        // Free tier keeps the first N build habits active and pauses the rest; quit habits
        // are always active, whatever the plan.
        let split = services.premium.partition(allHabits)
        let habits = split.active
        let lockedHabits = split.paused
        let fraction = viewModel.dayCompletionFraction(habits: habits)
        let openHabits = habits.filter { !viewModel.state(for: $0).isDone }.count

        VStack(spacing: FMTheme.Spacing.lg) {
            DayHeaderView(journey: journey, completionFraction: fraction, userName: user?.name)

            if activeStake == nil,
               StakeInvitation.shouldOffer(
                   dayNumber: journey.dayNumber(),
                   habitCount: habits.count,
                   longestStreak: habits.map { $0.currentStreak() }.max() ?? 0,
                   dismissedOnDay: stakeOfferDismissedDay
               ) {
                StakeOfferCard(
                    onStart: { showStakeSetup = true },
                    onDismiss: { withAnimation { stakeOfferDismissedDay = journey.dayNumber() } }
                )
                .padding(.horizontal, FMTheme.Spacing.md)
            }

            if let challenge = activeStake {
                // Above the streak cards deliberately: it is the only thing on this screen
                // that can cost the user something real today.
                StakeCard(
                    challenge: challenge,
                    status: StakeRules.status(for: challenge, habits: habits)
                ) { showStakeDetail = true }
                .padding(.horizontal, FMTheme.Spacing.md)
            }

            if !habits.isEmpty {
                // The two highest-intent moments in the whole app: a streak about to
                // break, and the morning after one did.
                if showComebackCard(habits: habits) {
                    ComebackCard(
                        streakAtStake: StreakFreezeService.recoverableStreak(habits: habits),
                        freezesRemaining: freezesRemaining
                    ) {
                        useStreakFreeze(habits: habits)
                    } onContinue: {
                        withAnimation { dismissedComeback = true }
                        services.analytics.track(.comebackAfterMissedDay(dayNumber: journey.dayNumber()))
                    }
                    .padding(.horizontal, FMTheme.Spacing.md)
                } else if StreakFreezeService.isStreakAtRisk(habits: habits), openHabits > 0 {
                    StreakAtRiskBanner(
                        streakDays: StreakFreezeService.streakAtStake(habits: habits),
                        remainingHabits: openHabits
                    ) {
                        if let next = habits.first(where: { !viewModel.state(for: $0).isDone }) {
                            handleTap(habit: next, viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, FMTheme.Spacing.md)
                } else if let milestone = ReelPrompt.milestone(
                    day: journey.dayNumber(),
                    lastPromptedDay: reelPromptedDay
                ) {
                    // Deliberately last: a streak about to break or one already broken is
                    // a more urgent thing to say than "nice milestone, post about it".
                    ReelPromptCard(milestone: milestone, totalDays: journey.lengthInDays) {
                        reelPromptedDay = journey.dayNumber()
                        showReel = true
                    } onDismiss: {
                        withAnimation { reelPromptedDay = journey.dayNumber() }
                    }
                    .padding(.horizontal, FMTheme.Spacing.md)
                    .onAppear {
                        services.analytics.track(.reelPromptShown(dayNumber: journey.dayNumber()))
                    }
                }
            }

            if habits.isEmpty {
                TodayEmptyState { showCreateHabit = true }
            } else {
                VStack(spacing: FMTheme.Spacing.sm) {
                    ForEach(habits) { habit in
                        if habit.isQuit {
                            QuitCounterCard(habit: habit) { quitHabitForDetail = habit }
                        } else {
                            HabitRowCard(
                                habit: habit,
                                state: viewModel.state(for: habit),
                                progress: viewModel.progress(for: habit),
                                completion: viewModel.completion(for: habit)
                            ) {
                                handleTap(habit: habit, viewModel: viewModel)
                            }
                            .onLongPressGesture {
                                Haptics.impact(.medium)
                                habitForDetail = habit
                            }
                        }
                    }
                }
                .padding(.horizontal, FMTheme.Spacing.md)

                if !lockedHabits.isEmpty {
                    VStack(spacing: FMTheme.Spacing.sm) {
                        ForEach(lockedHabits) { habit in
                            LockedHabitRow(habit: habit) {
                                services.analytics.track(.featureGateHit(feature: PremiumFeature.unlimitedHabits.rawValue))
                                paywallTrigger = .habitLimit
                            }
                        }
                    }
                    .padding(.horizontal, FMTheme.Spacing.md)
                }

                if !services.premium.isPremium {
                    FreeTierFooter(habitCount: habits.filter(PremiumGate.countsTowardLimit).count) {
                        paywallTrigger = .habitLimit
                    }
                    .padding(.horizontal, FMTheme.Spacing.md)
                }

                FMSecondaryButton(title: "Finish your day") {
                    showNightReview = true
                }
                .padding(.horizontal, FMTheme.Spacing.md)
                .padding(.top, FMTheme.Spacing.sm)
            }
        }
        .padding(.bottom, FMTheme.Spacing.xxl)
    }

    // MARK: - Interaction

    private func handleTap(habit: Habit, viewModel: TodayViewModel) {
        guard !viewModel.state(for: habit).isDone else { return }
        switch habit.verificationType {
        case .photoAI, .hybrid:
            // Free tier gets a real taste of AI verification, then a contextual upgrade.
            guard services.premium.canUseAIVerification else {
                services.analytics.track(.featureGateHit(feature: PremiumFeature.unlimitedAIVerification.rawValue))
                paywallTrigger = .aiVerificationQuota
                return
            }
            verifyingHabit = habit
        case .manual:
            if habit.goalTargetValue > 1 {
                waterHabitForLogging = habit
            } else {
                viewModel.markManualComplete(habit)
                stakeDidChange()
            }
        case .timer:
            viewModel.markManualComplete(habit)
            stakeDidChange()
        case .healthKit, .location:
            // Progress arrives passively from HealthKit/location; tapping just refreshes.
            Task {
                await services.healthKit.refreshTodayMetrics()
                syncHealthKit(journey: journey)
                stakeDidChange()
            }
        }
    }

    private func requestAddHabit() {
        // Counts paused habits, but not quit habits — those are never limited.
        let count = (journey?.habits ?? []).filter(PremiumGate.countsTowardLimit).count
        guard services.premium.canAddHabit(currentCount: count) else {
            services.analytics.track(.featureGateHit(feature: PremiumFeature.unlimitedHabits.rawValue))
            paywallTrigger = .habitLimit
            return
        }
        showCreateHabit = true
    }

    // MARK: - Streak protection

    private var freezesRemaining: Int {
        guard let user else { return 0 }
        return StreakFreezeService.remainingFreezes(for: user, gate: services.premium)
    }

    private var activeStake: StakeChallenge? { challenges.first(where: \.isActive) }

    /// Re-checks the challenge and records the moment it ends. Called on appear and after
    /// every habit change, because "you missed yesterday" has to be told at the first
    /// opportunity rather than whenever the user next happens to open this screen.
    private func refreshStake() {
        guard let challenge = activeStake, let journey else { return }
        StakeService(modelContext: modelContext).refresh(challenge, habits: journey.habits)
    }

    /// Called after any habit change.
    ///
    /// Finishing the last open habit is exactly what should stand tonight's "you'll lose
    /// it" warning down. Leaving it scheduled after the day is already safe is the fastest
    /// way to teach someone that these notifications lie, and then they stop reading the
    /// one that matters.
    private func stakeDidChange() {
        refreshStake()
    }

    /// iOS only honours three rating prompts a year, so this asks on a good day or not
    /// at all — see `ReviewPrompt` for the rules.
    private func askForReviewIfEarned() {
        guard let completedDay else { return }
        self.completedDay = nil

        let prompt = ReviewPrompt()
        let version = ReviewPrompt.currentAppVersion
        guard prompt.shouldAsk(dayNumber: completedDay.day, dailyScore: completedDay.score, appVersion: version)
        else { return }

        prompt.recordAsk(appVersion: version)
        requestReview()
    }

    private func showComebackCard(habits: [Habit]) -> Bool {
        !dismissedComeback
            && StreakFreezeService.missedYesterday(habits: habits)
            && StreakFreezeService.streakAtStake(habits: habits) == 0
    }

    private func useStreakFreeze(habits: [Habit]) {
        guard let user else { return }
        guard freezesRemaining > 0 else {
            paywallTrigger = .streakRepair
            return
        }
        let saved = StreakFreezeService.applyFreeze(
            user: user, habits: habits, gate: services.premium, context: modelContext
        )
        if saved {
            services.analytics.track(
                .streakSaved(daysProtected: StreakFreezeService.recoverableStreak(habits: habits))
            )
            withAnimation { dismissedComeback = true }
        }
    }

    // MARK: - Background wiring

    private func scheduleSmartReminders() {
        guard let journey else { return }
        SmartNotificationEngine.scheduleBehavioralReminders(
            journey: journey,
            notifications: services.notifications,
            stakeIsActive: activeStake != nil
        )
    }

    private func syncHealthKit(journey: Journey?) {
        guard let journey, let viewModel else { return }
        for habit in journey.habits where habit.verificationType == .healthKit || habit.verificationType == .hybrid {
            if habit.goalUnit == "steps" {
                viewModel.syncHealthKitProgress(habit, value: services.healthKit.todaySteps)
            } else if habit.goalUnit == "min" {
                viewModel.syncHealthKitProgress(habit, value: services.healthKit.todayExerciseMinutes)
            }
        }
    }

    /// Starts a fresh 90-day journey for the existing user (used after a completed
    /// transformation, or if the user has none yet) and immediately opens habit creation.
    private func startNewJourney() {
        let user = users.first ?? {
            let new = User()
            new.settings = UserSettings()
            modelContext.insert(new)
            return new
        }()

        let journey = Journey()
        journey.owner = user
        modelContext.insert(journey)
        try? modelContext.save()
        showCreateHabit = true
    }
}

/// Free-tier status line. Shows real remaining capacity rather than nagging — the
/// upgrade prompt only sharpens once the user is actually at the limit.
private struct FreeTierFooter: View {
    let habitCount: Int
    let onUpgrade: () -> Void

    private var remaining: Int { max(PremiumGate.freeHabitLimit - habitCount, 0) }

    var body: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 6) {
                Image(systemName: remaining == 0 ? "lock.fill" : "sparkles")
                    .font(.system(size: 12))
                Text(remaining == 0
                     ? "Habit limit reached — unlock unlimited habits"
                     : "\(remaining) free habit\(remaining == 1 ? "" : "s") left · Go Premium")
                    .font(FMTheme.Typography.footnote)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(FMTheme.Colors.textSecondary)
            .padding(.horizontal, FMTheme.Spacing.sm)
            .padding(.vertical, 10)
            .background(FMTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TodayEmptyState: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: FMTheme.Spacing.md) {
            Text("🌱").font(.system(size: 48))
            Text("Your comeback starts here.")
                .font(FMTheme.Typography.title2)
            Text("No habits yet. Build your first 90-day routine.")
                .font(FMTheme.Typography.body)
                .foregroundStyle(FMTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            FMPrimaryButton(title: "Create a habit", icon: "plus", action: action)
                .padding(.top, FMTheme.Spacing.sm)
        }
        .padding(FMTheme.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    TodayView()
        .environment(AppState())
        .modelContainer(PreviewData.container)
}
