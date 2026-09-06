import SwiftUI
import SwiftData

struct HabitDetailView: View {
    @Bindable var habit: Habit
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private var last14Days: [(Date, HabitDayState)] {
        (0..<14).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now.startOfDay) ?? .now
            return (date, habit.completion(on: date)?.state ?? .notStarted)
        }
    }

    private var completionRate: Double {
        let total = habit.completions.count
        guard total > 0 else { return 0 }
        let done = habit.completions.filter { $0.state.isDone }.count
        return Double(done) / Double(total)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FMTheme.Spacing.lg) {
                header

                HStack(spacing: FMTheme.Spacing.sm) {
                    StatBlock(value: "\(habit.currentStreak())", label: "Streak", icon: "flame.fill")
                    StatBlock(value: "\(Int(completionRate * 100))%", label: "Completion", icon: "chart.bar.fill")
                    StatBlock(value: "\(habit.completions.filter { $0.state.isDone }.count)", label: "Total done", icon: "checkmark.circle.fill")
                }

                VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
                    Text("Last 14 days").font(FMTheme.Typography.headline).foregroundStyle(FMTheme.Colors.textPrimary)
                    HStack(spacing: 4) {
                        ForEach(last14Days, id: \.0) { _, state in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(state.isDone ? FMTheme.Colors.forCategory(habit.category) : (state == .missed ? FMTheme.Colors.danger.opacity(0.3) : FMTheme.Colors.surfaceElevated))
                                .frame(height: 28)
                        }
                    }
                }
                .padding(FMTheme.Spacing.md)
                .background(FMTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))

                VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
                    DetailRow(title: "Verification", value: habit.verificationType.label)
                    DetailRow(title: "Goal", value: habit.goalDescription)
                    if habit.isReminderEnabled, let time = habit.reminderTime {
                        DetailRow(title: "Reminder", value: time.formattedTime())
                    }
                }
                .padding(FMTheme.Spacing.md)
                .background(FMTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text("Delete habit").font(FMTheme.Typography.headline)
                }
                .padding(.top, FMTheme.Spacing.sm)
            }
            .padding(FMTheme.Spacing.lg)
        }
        .background(FMTheme.Colors.background)
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this habit?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(habit)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(spacing: FMTheme.Spacing.sm) {
            Image(systemName: habit.iconSystemName)
                .font(.system(size: 32))
                .foregroundStyle(FMTheme.Colors.forCategory(habit.category))
                .frame(width: 72, height: 72)
                .background(FMTheme.Colors.forCategory(habit.category).opacity(0.15))
                .clipShape(Circle())
            StreakBadge(days: habit.currentStreak())
        }
    }
}

private struct StatBlock: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(FMTheme.Colors.accent)
            Text(value).font(FMTheme.Typography.title2).foregroundStyle(FMTheme.Colors.textPrimary)
            Text(label).font(FMTheme.Typography.footnote).foregroundStyle(FMTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FMTheme.Spacing.sm)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).font(FMTheme.Typography.body).foregroundStyle(FMTheme.Colors.textSecondary)
            Spacer()
            Text(value).font(FMTheme.Typography.body).foregroundStyle(FMTheme.Colors.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(habit: HabitCatalog.all[3].makeHabit())
    }
    .modelContainer(PreviewData.container)
}
