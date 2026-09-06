import SwiftUI
import SwiftData

/// Relapse logging.
///
/// The single most important screen in a quit tracker, and the one most apps get wrong.
/// It leads with what the user keeps rather than what they lost, because someone who
/// feels judged here deletes the app instead of starting the next run.
struct RelapseSheet: View {
    let habit: Habit

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var trigger = ""

    private var runLength: String {
        QuitProgressCalculator.formatted(QuitProgressCalculator.cleanTime(for: habit))
    }

    private var totalClean: String {
        QuitProgressCalculator.formatted(QuitProgressCalculator.totalCleanTime(for: habit))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FMTheme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                        Text("It happened.")
                            .font(FMTheme.Typography.display(30))
                            .foregroundStyle(FMTheme.Colors.textPrimary)
                        Text("That doesn't erase the \(runLength) you just did. Almost nobody quits on the first run — the people who get there are the ones who start again.")
                            .font(FMTheme.Typography.body)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: FMTheme.Spacing.sm) {
                        KeptRow(label: "Total time clean, all attempts", value: totalClean)
                        KeptRow(label: "Longest run", value: QuitProgressCalculator.formatted(QuitProgressCalculator.longestRun(for: habit)))
                        KeptRow(label: "Cravings you rode out", value: "\(QuitProgressCalculator.cravingsResisted(for: habit))")
                    }
                    .padding(FMTheme.Spacing.md)
                    .background(FMTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))

                    VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                        Text("What led to it? (optional)")
                            .font(FMTheme.Typography.headline)
                            .foregroundStyle(FMTheme.Colors.textPrimary)
                        Text("Only useful for spotting your own patterns. Skip it if you'd rather not.")
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                        TextField("Stress, a night out, boredom…", text: $trigger, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(FMTheme.Spacing.sm)
                            .background(FMTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                    }

                    FMPrimaryButton(title: "Start my next run", icon: "arrow.clockwise") {
                        QuitProgressCalculator.recordRelapse(
                            for: habit, trigger: trigger, context: modelContext
                        )
                        Haptics.impact(.medium)
                        dismiss()
                    }
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Reset the counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

private struct KeptRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textSecondary)
            Spacer(minLength: FMTheme.Spacing.sm)
            Text(value)
                .font(FMTheme.Typography.subheadline)
                .foregroundStyle(FMTheme.Colors.textPrimary)
                .monospacedDigit()
        }
    }
}

#Preview {
    RelapseSheet(habit: Habit(
        name: "No smoking", iconSystemName: "nosign", category: .health,
        verificationType: .manual, goalDescription: "Stay smoke-free",
        kind: .quit, quitProgramID: "smoking",
        quitStartDate: Calendar.current.date(byAdding: .day, value: -12, to: .now)
    ))
    .modelContainer(PreviewData.container)
}
