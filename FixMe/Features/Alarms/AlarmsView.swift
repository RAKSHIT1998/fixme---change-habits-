import SwiftUI
import SwiftData

struct AlarmsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Query(sort: \HabitAlarm.time) private var alarms: [HabitAlarm]
    @Query private var journeys: [Journey]

    @State private var editingAlarm: HabitAlarm?
    @State private var showNewAlarm = false
    @State private var showLoudInfo = false

    var body: some View {
        NavigationStack {
            Group {
                if alarms.isEmpty {
                    ContentUnavailableView {
                        Label("No alarms yet", systemImage: "alarm")
                    } description: {
                        Text("Set one for the habit you keep forgetting. It'll wake you up with a Done button right on the lock screen.")
                    } actions: {
                        Button("Add an alarm") { showNewAlarm = true }
                            .buttonStyle(.borderedProminent)
                            .tint(FMTheme.Colors.accent)
                    }
                } else {
                    List {
                        Section {
                            LoudModeRow(
                                isOn: Binding(
                                    get: { services.alarms.audio.loudModeEnabled },
                                    set: { newValue in
                                        services.alarms.audio.loudModeEnabled = newValue
                                        Haptics.selection()
                                        Task { await services.alarms.refreshScheduledAlarms() }
                                    }
                                ),
                                onInfo: { showLoudInfo = true }
                            )
                        } header: {
                            Text("Volume")
                        } footer: {
                            Text(services.alarms.audio.loudModeEnabled
                                 ? "Fix Me stays awake so alarms play at full volume, even on Silent. This uses noticeably more battery."
                                 : "Alarms currently arrive as notifications, so the Silent switch mutes them.")
                        }

                        Section {
                            ForEach(alarms) { alarm in
                                AlarmRow(alarm: alarm) {
                                    Task { await AlarmScheduler.reschedule(alarm) }
                                    try? modelContext.save()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { editingAlarm = alarm }
                            }
                            .onDelete(perform: delete)
                        } footer: {
                            AlarmLimitationNotice()
                        }
                    }
                }
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewAlarm = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showNewAlarm) {
                AlarmEditorView(alarm: nil, habits: allHabits)
            }
            .sheet(item: $editingAlarm) { alarm in
                AlarmEditorView(alarm: alarm, habits: allHabits)
            }
            .alert("Loud alarm", isPresented: $showLoudInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("iOS won't let a notification sound override the Silent switch. So Fix Me keeps a silent audio track running to stay awake, then plays the alarm itself at full volume — the same approach dedicated alarm apps use.\n\nThe cost is battery: the app never fully sleeps while this is on. Leave it off unless you actually rely on the alarm to wake you.")
            }
            .task {
                _ = await services.notifications.requestAuthorization()
                await services.alarms.refreshScheduledAlarms()
            }
        }
    }

    private var allHabits: [Habit] {
        journeys.filter(\.isActive).flatMap(\.habits).sorted { $0.sortOrder < $1.sortOrder }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let alarm = alarms[index]
            AlarmScheduler.cancel(alarm)
            modelContext.delete(alarm)
        }
        try? modelContext.save()
    }
}

/// Explains, before someone relies on an alarm, exactly how far it can go — which now
/// depends on whether loud mode is on.
struct AlarmLimitationNotice: View {
    @Environment(\.services) private var services

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
            Text(services.alarms.audio.loudModeEnabled
                 ? "With Loud alarm on, Fix Me plays the alarm itself at full volume and ignores the Silent switch. If iOS shuts the app down to reclaim memory it falls back to a notification, so for anything truly unmissable keep a Clock alarm as backup."
                 : "Alarms arrive as Time Sensitive notifications: they break through most Focus modes, but the Silent switch still mutes them and they stop after 30 seconds. Turn on Loud alarm above to have Fix Me play the sound itself instead.")
        }
        .font(.system(size: 11))
        .foregroundStyle(FMTheme.Colors.textTertiary)
        .padding(.top, FMTheme.Spacing.xs)
    }
}

private struct LoudModeRow: View {
    @Binding var isOn: Bool
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: FMTheme.Spacing.sm) {
            Image(systemName: isOn ? "speaker.wave.3.fill" : "speaker.slash.fill")
                .foregroundStyle(isOn ? FMTheme.Colors.accent : FMTheme.Colors.textTertiary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text("Loud alarm").font(FMTheme.Typography.headline)
                Text("Full volume, ignores Silent")
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
            Button(action: onInfo) {
                Image(systemName: "info.circle").foregroundStyle(FMTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            Toggle("", isOn: $isOn).labelsHidden().tint(FMTheme.Colors.accent)
        }
    }
}

private struct AlarmRow: View {
    @Bindable var alarm: HabitAlarm
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: FMTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.time, style: .time)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(alarm.isEnabled ? FMTheme.Colors.textPrimary : FMTheme.Colors.textTertiary)

                Text(alarm.label)
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)

                HStack(spacing: 4) {
                    Text(alarm.repeatSummary)
                    if let habit = alarm.habit {
                        Text("·")
                        Text(habit.name)
                    }
                }
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textTertiary)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: $alarm.isEnabled)
                .labelsHidden()
                .tint(FMTheme.Colors.accent)
                .onChange(of: alarm.isEnabled) { _, _ in
                    Haptics.selection()
                    onToggle()
                }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AlarmsView().modelContainer(PreviewData.container)
}
