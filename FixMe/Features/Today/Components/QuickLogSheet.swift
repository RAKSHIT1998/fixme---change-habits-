import SwiftUI

/// Quick manual-log sheet for habits like water, where the user adds partial progress
/// (e.g. 250ml at a time) rather than doing a single tap-to-complete.
struct QuickLogSheet: View {
    let habit: Habit
    let onLog: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    private var presets: [Double] {
        habit.goalUnit == "ml" ? [250, 500, 750] : [1, 5, 10]
    }

    var body: some View {
        VStack(spacing: FMTheme.Spacing.lg) {
            Capsule().fill(FMTheme.Colors.textTertiary.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 8)

            VStack(spacing: 4) {
                Text(habit.name).font(FMTheme.Typography.title2)
                Text("Log your progress").font(FMTheme.Typography.body).foregroundStyle(FMTheme.Colors.textSecondary)
            }

            HStack(spacing: FMTheme.Spacing.sm) {
                ForEach(presets, id: \.self) { amount in
                    Button {
                        onLog(amount)
                        Haptics.impact(.light)
                        dismiss()
                    } label: {
                        Text("+\(Int(amount))\(habit.goalUnit)")
                            .font(FMTheme.Typography.headline)
                            .foregroundStyle(FMTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(FMTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FMTheme.Spacing.lg)

            Spacer()
        }
        .background(FMTheme.Colors.background)
    }
}

#Preview {
    QuickLogSheet(habit: HabitCatalog.all[2].makeHabit(), onLog: { _ in })
}
