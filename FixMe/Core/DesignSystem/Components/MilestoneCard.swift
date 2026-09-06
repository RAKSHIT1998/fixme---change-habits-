import SwiftUI

struct MilestoneCard: View {
    let milestone: Milestone
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: FMTheme.Spacing.sm) {
            Text(milestone.emoji).font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text("DAY \(milestone.day)").font(FMTheme.Typography.caption).foregroundStyle(FMTheme.Colors.textSecondary)
                Text(milestone.title).font(FMTheme.Typography.headline).foregroundStyle(FMTheme.Colors.textPrimary)
            }
            Spacer()
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(FMTheme.Colors.accent)
            } else {
                Image(systemName: "lock.fill").foregroundStyle(FMTheme.Colors.textTertiary)
            }
        }
        .padding(FMTheme.Spacing.md)
        .background(isUnlocked ? FMTheme.Colors.accent.opacity(0.1) : FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous)
                .stroke(isUnlocked ? FMTheme.Colors.accent.opacity(0.3) : .clear, lineWidth: 1)
        )
        .scaleEffect(isUnlocked ? 1 : 0.98)
        .animation(FMTheme.Motion.bouncy, value: isUnlocked)
    }
}

#Preview {
    VStack {
        MilestoneCard(milestone: Milestone.all[0], isUnlocked: true)
        MilestoneCard(milestone: Milestone.all[3], isUnlocked: false)
    }
    .padding()
}
