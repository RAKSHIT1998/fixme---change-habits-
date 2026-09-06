import SwiftUI

/// A habit the user set up but that sits beyond the free tier's limit.
///
/// Deliberately *not* deleted: the user chose it during onboarding, and destroying their
/// setup to sell a subscription would be both hostile and bad business. It stays visible,
/// in their list, one tap from being active again — which is a far better daily reminder
/// of what Premium does than any banner.
struct LockedHabitRow: View {
    let habit: Habit
    let onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            HStack(spacing: FMTheme.Spacing.sm) {
                Image(systemName: habit.iconSystemName)
                    .font(.system(size: 20))
                    .foregroundStyle(FMTheme.Colors.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(FMTheme.Colors.surfaceElevated)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(FMTheme.Typography.headline)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                    Text("Paused — beyond your \(PremiumGate.freeHabitLimit) free habits")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textTertiary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                    Text("UNLOCK").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(FMTheme.Colors.accent)
                .clipShape(Capsule())
            }
            .padding(FMTheme.Spacing.sm)
            .background(FMTheme.Colors.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.name), paused. Unlock with Premium.")
    }
}

#Preview {
    LockedHabitRow(habit: HabitCatalog.all[4].makeHabit(), onUnlock: {})
        .padding()
}
