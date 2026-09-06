import SwiftUI

/// Today-screen card for a quit habit. Shows live clean time rather than a checkbox,
/// because "how long have I held on" is the number that actually motivates here.
struct QuitCounterCard: View {
    let habit: Habit
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: FMTheme.Spacing.sm) {
                Text(habit.quitProgram?.emoji ?? "🎯")
                    .font(.system(size: 24))
                    .frame(width: 44, height: 44)
                    .background(FMTheme.Colors.success.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(FMTheme.Typography.headline)
                        .foregroundStyle(FMTheme.Colors.textPrimary)

                    // Ticks once a minute here; the detail screen ticks every second.
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(QuitProgressCalculator.formatted(
                            QuitProgressCalculator.cleanTime(for: habit, now: context.date)
                        ) + " free")
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.success)
                            .monospacedDigit()
                    }
                }

                Spacer(minLength: 0)

                if habit.relapsed(on: .now) {
                    Text("Reset today")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textTertiary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FMTheme.Colors.success)
                }
            }
            .padding(FMTheme.Spacing.sm)
            .background(FMTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.name), clean for \(QuitProgressCalculator.formatted(QuitProgressCalculator.cleanTime(for: habit)))")
    }
}

#Preview {
    QuitCounterCard(
        habit: Habit(
            name: "No smoking", iconSystemName: "nosign", category: .health,
            verificationType: .manual, goalDescription: "Stay smoke-free",
            kind: .quit, quitProgramID: "smoking",
            quitStartDate: Calendar.current.date(byAdding: .day, value: -12, to: .now),
            unitsPerDay: 10, costPerUnit: 0.5
        ),
        onTap: {}
    )
    .padding()
}
