import SwiftUI
import SwiftData

struct AlarmEditorView: View {
    /// Nil when creating a new alarm.
    let alarm: HabitAlarm?
    let habits: [Habit]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var time = Date.fromComponents(hour: 7, minute: 0)
    @State private var label = "Time to show up"
    @State private var weekdays: Set<Int> = []
    @State private var snoozeMinutes = 10
    @State private var linkedHabitID: UUID?
    @State private var loaded = false

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }

                Section("Repeat") {
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { day in
                            Button {
                                Haptics.selection()
                                if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
                            } label: {
                                Text(weekdaySymbols[day - 1].prefix(1))
                                    .font(FMTheme.Typography.caption)
                                    .frame(width: 36, height: 36)
                                    .background(weekdays.contains(day) ? FMTheme.Colors.accent : FMTheme.Colors.surfaceElevated)
                                    .foregroundStyle(weekdays.contains(day) ? .white : FMTheme.Colors.textPrimary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Text(weekdays.isEmpty ? "Every day" : "Selected days only")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }

                Section("Label") {
                    TextField("Label", text: $label)
                }

                Section("Habit") {
                    Picker("Marks done", selection: $linkedHabitID) {
                        Text("None").tag(UUID?.none)
                        ForEach(habits) { habit in
                            Text(habit.name).tag(UUID?.some(habit.id))
                        }
                    }
                    Text("Linking a habit puts a Done button on the notification, so you can log it without opening the app.")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }

                Section("Snooze") {
                    Stepper("\(snoozeMinutes) minutes", value: $snoozeMinutes, in: 1...60)
                }

                Section { AlarmLimitationNotice() }
            }
            .navigationTitle(alarm == nil ? "New Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func loadExisting() {
        guard !loaded, let alarm else { loaded = true; return }
        time = alarm.time
        label = alarm.label
        weekdays = Set(alarm.weekdays)
        snoozeMinutes = alarm.snoozeMinutes
        linkedHabitID = alarm.habit?.id
        loaded = true
    }

    private func save() {
        let target = alarm ?? HabitAlarm()
        target.time = time
        target.label = label.isEmpty ? "Time to show up" : label
        target.weekdays = Array(weekdays)
        target.snoozeMinutes = snoozeMinutes
        target.habit = habits.first { $0.id == linkedHabitID }
        target.isEnabled = true

        if alarm == nil { modelContext.insert(target) }
        try? modelContext.save()

        Task { await AlarmScheduler.reschedule(target) }
        Haptics.notify(.success)
        dismiss()
    }
}

#Preview {
    AlarmEditorView(alarm: nil, habits: [])
        .modelContainer(PreviewData.container)
}
