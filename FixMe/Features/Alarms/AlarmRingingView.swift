import SwiftUI
import SwiftData

/// Full-screen alarm, shown when an alarm fires while the app is open or its notification
/// is tapped. Deliberately loud and single-purpose: two big targets, nothing else to do.
struct AlarmRingingView: View {
    let alarm: HabitAlarm
    let onDone: () -> Void
    let onSnooze: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [FMTheme.Colors.accent, FMTheme.Colors.accent.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: FMTheme.Spacing.lg) {
                Spacer()

                Image(systemName: "alarm.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
                    .scaleEffect(reduceMotion ? 1 : (pulse ? 1.1 : 0.95))
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                        value: pulse
                    )

                VStack(spacing: FMTheme.Spacing.xs) {
                    Text(alarm.time, style: .time)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text(alarm.label)
                        .font(FMTheme.Typography.title2)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)

                    if let habit = alarm.habit {
                        Text("\(habit.name) · \(habit.goalDescription)")
                            .font(FMTheme.Typography.body)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(.horizontal, FMTheme.Spacing.lg)

                Spacer()

                VStack(spacing: FMTheme.Spacing.sm) {
                    Button(action: onDone) {
                        Text(alarm.habit == nil ? "I'm up" : "Mark done")
                            .font(FMTheme.Typography.headline)
                            .foregroundStyle(FMTheme.Colors.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onSnooze) {
                        Text("Snooze \(alarm.snoozeMinutes) min")
                            .font(FMTheme.Typography.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, FMTheme.Spacing.lg)
                .padding(.bottom, FMTheme.Spacing.xl)
            }
        }
        .onAppear {
            pulse = true
            Haptics.notify(.warning)
        }
    }
}

#Preview {
    AlarmRingingView(alarm: HabitAlarm(label: "Wake up. Day 18 is waiting."), onDone: {}, onSnooze: {})
}
