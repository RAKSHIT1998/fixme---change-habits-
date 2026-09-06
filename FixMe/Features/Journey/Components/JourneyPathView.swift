import SwiftUI

/// Renders the 90-day journey as a winding path rather than a flat calendar grid —
/// day dots alternate left/right, with milestone cards breaking up the rhythm.
struct JourneyPathView: View {
    let journey: Journey
    @Binding var selectedDay: Int?

    private var currentDay: Int { journey.dayNumber() }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(1...journey.lengthInDays, id: \.self) { day in
                dayRow(day)
                if let milestone = Milestone.milestone(for: day) {
                    MilestoneCard(milestone: milestone, isUnlocked: day <= currentDay)
                        .padding(.vertical, FMTheme.Spacing.sm)
                }
            }
        }
        .padding(.horizontal, FMTheme.Spacing.lg)
    }

    @ViewBuilder
    private func dayRow(_ day: Int) -> some View {
        let isLeft = (day / 7) % 2 == 0
        HStack {
            if isLeft {
                dayDot(day)
                Spacer()
            } else {
                Spacer()
                dayDot(day)
            }
        }
        .frame(height: 46)
    }

    private func dayDot(_ day: Int) -> some View {
        Button {
            Haptics.selection()
            selectedDay = day
        } label: {
            ZStack {
                Circle()
                    .fill(fillColor(for: day))
                    .frame(width: day == currentDay ? 40 : 30, height: day == currentDay ? 40 : 30)
                if day == currentDay {
                    Circle().stroke(FMTheme.Colors.accent, lineWidth: 3).frame(width: 46, height: 46)
                }
                Text("\(day)")
                    .font(.system(size: day == currentDay ? 14 : 11, weight: .bold, design: .rounded))
                    .foregroundStyle(day <= currentDay ? .white : FMTheme.Colors.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func fillColor(for day: Int) -> Color {
        if day < currentDay { return FMTheme.Colors.accent.opacity(0.7) }
        if day == currentDay { return FMTheme.Colors.accent }
        return FMTheme.Colors.surfaceElevated
    }
}

#Preview {
    ScrollView {
        JourneyPathView(
            journey: Journey(startDate: Calendar.current.date(byAdding: .day, value: -16, to: .now) ?? .now),
            selectedDay: .constant(nil)
        )
    }
}
