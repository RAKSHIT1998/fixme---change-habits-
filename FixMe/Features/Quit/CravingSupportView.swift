import SwiftUI
import SwiftData

/// "Urge surfing" — ride the craving out instead of fighting it.
///
/// Cravings are self-limiting; most peak and pass within a few minutes. Giving someone a
/// timed, paced thing to do during that window is the single most practical feature a
/// quit tracker can offer, and it turns the craving into logged progress rather than a
/// near-miss nobody sees.
struct CravingSupportView: View {
    let habit: Habit

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var intensity = 3
    @State private var isRunning = false
    @State private var secondsRemaining = 300
    @State private var breatheIn = false
    @State private var showRelapse = false

    private let totalSeconds = 300
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var progress: Double {
        1 - (Double(secondsRemaining) / Double(totalSeconds))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: FMTheme.Spacing.lg) {
                if isRunning {
                    runningState
                } else {
                    setupState
                }
            }
            .padding(FMTheme.Spacing.lg)
            .background(FMTheme.Colors.background)
            .navigationTitle("Craving")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
            .onReceive(timer) { _ in tick() }
            .sheet(isPresented: $showRelapse) {
                RelapseSheet(habit: habit)
            }
        }
    }

    // MARK: - States

    private var setupState: some View {
        VStack(spacing: FMTheme.Spacing.lg) {
            Spacer()

            Text("🌊").font(.system(size: 56))

            VStack(spacing: FMTheme.Spacing.xs) {
                Text("Ride it out.")
                    .font(FMTheme.Typography.display(30))
                    .foregroundStyle(FMTheme.Colors.textPrimary)
                Text("Cravings rise, peak and fade — usually within a few minutes. You don't have to fight it. Just outlast it.")
                    .font(FMTheme.Typography.body)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: FMTheme.Spacing.xs) {
                Text("How strong is it?")
                    .font(FMTheme.Typography.subheadline)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
                HStack(spacing: FMTheme.Spacing.xs) {
                    ForEach(1...5, id: \.self) { level in
                        Button {
                            Haptics.selection()
                            intensity = level
                        } label: {
                            Text("\(level)")
                                .font(FMTheme.Typography.headline)
                                .frame(width: 48, height: 48)
                                .background(intensity == level ? FMTheme.Colors.accent : FMTheme.Colors.surface)
                                .foregroundStyle(intensity == level ? .white : FMTheme.Colors.textPrimary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            FMPrimaryButton(title: "Start 5 minutes", icon: "play.fill") {
                isRunning = true
                breatheIn = true
            }
            Button("I already gave in") { showRelapse = true }
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textTertiary)
        }
    }

    private var runningState: some View {
        VStack(spacing: FMTheme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(FMTheme.Colors.surfaceElevated, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(FMTheme.Colors.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Paced breathing guide, 4s in / 4s out. Static when Reduce Motion is on.
                Circle()
                    .fill(FMTheme.Colors.accent.opacity(0.15))
                    .frame(width: reduceMotion ? 150 : (breatheIn ? 190 : 120),
                           height: reduceMotion ? 150 : (breatheIn ? 190 : 120))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 4), value: breatheIn)

                VStack(spacing: 2) {
                    Text(timeLabel)
                        .font(FMTheme.Typography.display(34))
                        .monospacedDigit()
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    Text(reduceMotion ? "Keep breathing" : (breatheIn ? "Breathe in" : "Breathe out"))
                        .font(FMTheme.Typography.caption)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }
            }
            .frame(width: 240, height: 240)

            Text(encouragement)
                .font(FMTheme.Typography.headline)
                .foregroundStyle(FMTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FMTheme.Spacing.md)

            Spacer()

            FMPrimaryButton(title: "It passed", icon: "checkmark") { finish(resisted: true) }
            Button("I gave in") { showRelapse = true }
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textTertiary)
        }
    }

    // MARK: - Logic

    private var timeLabel: String {
        String(format: "%d:%02d", secondsRemaining / 60, secondsRemaining % 60)
    }

    private var encouragement: String {
        switch secondsRemaining {
        case 240...: return "It's already peaking. Stay with it."
        case 180..<240: return "You're doing the hard part right now."
        case 60..<180: return "It's fading. Keep going."
        case 1..<60: return "Almost through it."
        default: return "You outlasted it."
        }
    }

    private func tick() {
        guard isRunning, secondsRemaining > 0 else { return }
        secondsRemaining -= 1
        if secondsRemaining % 4 == 0 { breatheIn.toggle() }
        if secondsRemaining == 0 {
            Haptics.notify(.success)
        }
    }

    private func finish(resisted: Bool) {
        QuitProgressCalculator.recordCraving(
            for: habit,
            intensity: intensity,
            didResist: resisted,
            durationSeconds: totalSeconds - secondsRemaining,
            context: modelContext
        )
        // Resisting is real work — it earns the same XP as completing a habit.
        if resisted, let user = habit.journey?.owner {
            user.totalXP += XPService.habitCompletionXP
            try? modelContext.save()
        }
        Haptics.notify(.success)
        dismiss()
    }
}

#Preview {
    CravingSupportView(habit: Habit(
        name: "No smoking", iconSystemName: "nosign", category: .health,
        verificationType: .manual, goalDescription: "Stay smoke-free",
        kind: .quit, quitProgramID: "smoking", quitStartDate: .now
    ))
    .modelContainer(PreviewData.container)
}
