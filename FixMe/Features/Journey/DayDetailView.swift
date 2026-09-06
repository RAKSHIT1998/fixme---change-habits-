import SwiftUI

struct DayDetailView: View {
    let journey: Journey
    let dayNumber: Int
    @Environment(\.dismiss) private var dismiss

    private var date: Date {
        Calendar.current.date(byAdding: .day, value: dayNumber - 1, to: journey.startDate) ?? journey.startDate
    }

    private var habitsWithCompletions: [(Habit, HabitCompletion?)] {
        journey.habits.sorted { $0.sortOrder < $1.sortOrder }.map { ($0, $0.completion(on: date)) }
    }

    private var dailyScore: Int {
        let total = habitsWithCompletions.count
        guard total > 0 else { return 0 }
        let done = habitsWithCompletions.filter { $0.1?.state.isDone == true }.count
        return Int((Double(done) / Double(total) * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FMTheme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DAY \(dayNumber)").font(FMTheme.Typography.caption).foregroundStyle(FMTheme.Colors.textSecondary)
                        Text(date.formattedWeekdayDate()).font(FMTheme.Typography.title2)
                    }

                    HStack {
                        Text("Daily score").font(FMTheme.Typography.body).foregroundStyle(FMTheme.Colors.textSecondary)
                        Spacer()
                        Text("\(dailyScore)").font(FMTheme.Typography.title)
                    }
                    .padding(FMTheme.Spacing.md)
                    .background(FMTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))

                    VStack(spacing: FMTheme.Spacing.xs) {
                        ForEach(habitsWithCompletions, id: \.0.id) { habit, completion in
                            HStack(spacing: FMTheme.Spacing.sm) {
                                Image(systemName: (completion?.state.isDone ?? false) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle((completion?.state.isDone ?? false) ? FMTheme.Colors.success : FMTheme.Colors.textTertiary)
                                Text(habit.name).font(FMTheme.Typography.body).foregroundStyle(FMTheme.Colors.textPrimary)
                                Spacer()
                                Text(completion?.state.label ?? "Missed")
                                    .font(FMTheme.Typography.footnote)
                                    .foregroundStyle(FMTheme.Colors.textSecondary)
                            }
                            .padding(FMTheme.Spacing.sm)
                            .background(FMTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                        }
                    }
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DayDetailView(journey: Journey(), dayNumber: 5)
}
