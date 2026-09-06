import SwiftUI
import SwiftData

/// The detail screen for a quit habit: live clean time, what it's bought you, the
/// recovery timeline, and the two actions that matter — ride out a craving, or log a
/// relapse honestly.
struct QuitTrackerView: View {
    let habit: Habit

    @Environment(\.modelContext) private var modelContext
    @State private var showCraving = false
    @State private var showRelapse = false

    private var program: QuitProgram? { habit.quitProgram }

    var body: some View {
        ScrollView {
            VStack(spacing: FMTheme.Spacing.lg) {
                counter
                statsGrid
                if let next = QuitProgressCalculator.nextMilestone(for: habit) {
                    nextMilestoneCard(next)
                }
                milestoneTimeline
                if let note = program?.safetyNote, !note.isEmpty {
                    safetyNote(note)
                }
                disclaimer
            }
            .padding(FMTheme.Spacing.lg)
            .padding(.bottom, 140)
        }
        .background(FMTheme.Colors.background)
        .safeAreaInset(edge: .bottom) { actionBar }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCraving) { CravingSupportView(habit: habit) }
        .sheet(isPresented: $showRelapse) { RelapseSheet(habit: habit) }
    }

    // MARK: - Counter

    private var counter: some View {
        VStack(spacing: FMTheme.Spacing.xs) {
            Text(program?.emoji ?? "🎯").font(.system(size: 44))

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let clean = QuitProgressCalculator.cleanTime(for: habit, now: context.date)
                VStack(spacing: 2) {
                    Text(QuitProgressCalculator.formatted(clean, includeSeconds: true))
                        .font(FMTheme.Typography.display(32))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    Text("free and counting")
                        .font(FMTheme.Typography.subheadline)
                        .foregroundStyle(FMTheme.Colors.success)
                }
            }

            if let start = habit.quitStartDate {
                Text("Since \(start.formattedShort()) at \(start.formattedTime())")
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FMTheme.Spacing.lg)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.xl, style: .continuous))
    }

    // MARK: - Stats

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FMTheme.Spacing.sm) {
            QuitStatTile(
                value: habit.moneySaved().formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                label: "Money saved",
                symbol: "banknote"
            )
            QuitStatTile(
                value: "\(habit.unitsAvoided())",
                label: "\(program?.unitName.capitalized ?? "Units") avoided",
                symbol: "nosign"
            )
            QuitStatTile(
                value: "\(QuitProgressCalculator.cravingsResisted(for: habit))",
                label: "Cravings beaten",
                symbol: "shield.fill"
            )
            QuitStatTile(
                value: QuitProgressCalculator.formatted(QuitProgressCalculator.longestRun(for: habit)),
                label: "Longest run",
                symbol: "trophy.fill"
            )
        }
    }

    // MARK: - Milestones

    private func nextMilestoneCard(_ milestone: RecoveryMilestone) -> some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
            Text("NEXT UP")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FMTheme.Colors.textTertiary)
            Text(milestone.title)
                .font(FMTheme.Typography.headline)
                .foregroundStyle(FMTheme.Colors.textPrimary)
            if !milestone.detail.isEmpty {
                Text(milestone.detail)
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ProgressView(value: QuitProgressCalculator.progressToNextMilestone(for: habit))
                .tint(FMTheme.Colors.accent)
                .padding(.top, 2)
            Text("at \(milestone.elapsedLabel) clean")
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
    }

    private var milestoneTimeline: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
            Text("Recovery timeline")
                .font(FMTheme.Typography.headline)
                .foregroundStyle(FMTheme.Colors.textPrimary)

            let reached = Set(QuitProgressCalculator.reachedMilestones(for: habit).map(\.hours))
            ForEach(program?.milestones ?? []) { milestone in
                HStack(alignment: .top, spacing: FMTheme.Spacing.sm) {
                    Image(systemName: reached.contains(milestone.hours) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(reached.contains(milestone.hours) ? FMTheme.Colors.success : FMTheme.Colors.textTertiary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(milestone.title)
                            .font(FMTheme.Typography.subheadline)
                            .foregroundStyle(reached.contains(milestone.hours) ? FMTheme.Colors.textPrimary : FMTheme.Colors.textSecondary)
                        if !milestone.detail.isEmpty {
                            Text(milestone.detail)
                                .font(FMTheme.Typography.footnote)
                                .foregroundStyle(FMTheme.Colors.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    Text(milestone.elapsedLabel)
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textTertiary)
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
    }

    // MARK: - Safety

    private func safetyNote(_ note: String) -> some View {
        HStack(alignment: .top, spacing: FMTheme.Spacing.sm) {
            Image(systemName: "cross.case.fill")
                .foregroundStyle(FMTheme.Colors.warning)
            Text(note)
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
    }

    private var disclaimer: some View {
        Text("Recovery timelines are general figures published by public health bodies, shown for motivation. They describe typical patterns — not a prediction about you, and not medical advice.")
            .font(.system(size: 11))
            .foregroundStyle(FMTheme.Colors.textTertiary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private var actionBar: some View {
        VStack(spacing: FMTheme.Spacing.xs) {
            FMPrimaryButton(title: "I'm having a craving", icon: "waveform.path") {
                showCraving = true
            }
            Button("Log a relapse") { showRelapse = true }
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textTertiary)
        }
        .padding(.horizontal, FMTheme.Spacing.lg)
        .padding(.vertical, FMTheme.Spacing.sm)
        .background(.ultraThinMaterial)
    }
}

struct QuitStatTile: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(FMTheme.Colors.accent)
            Text(value)
                .font(FMTheme.Typography.title2)
                .monospacedDigit()
                .foregroundStyle(FMTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FMTheme.Spacing.md)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        QuitTrackerView(habit: Habit(
            name: "No smoking", iconSystemName: "nosign", category: .health,
            verificationType: .manual, goalDescription: "Stay smoke-free",
            kind: .quit, quitProgramID: "smoking",
            quitStartDate: Calendar.current.date(byAdding: .day, value: -16, to: .now),
            unitsPerDay: 10, costPerUnit: 0.5
        ))
    }
    .modelContainer(PreviewData.container)
}
