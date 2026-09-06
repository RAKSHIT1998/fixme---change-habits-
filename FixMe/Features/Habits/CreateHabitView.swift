import SwiftUI
import SwiftData

/// Habit creation flow — supports both picking from the catalog and fully custom habits.
struct CreateHabitView: View {
    let journey: Journey
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var iconSystemName = "sparkles"
    @State private var category: HabitCategory = .custom
    @State private var verificationType: VerificationType = .manual
    @State private var goalDescription = ""
    @State private var goalTargetValue: Double = 1
    @State private var goalUnit = ""
    @State private var isReminderEnabled = false
    @State private var reminderTime = Date.fromComponents(hour: 8, minute: 0)
    @State private var kind: HabitKind = .build
    @State private var quitProgramID: String = QuitProgram.smoking.id
    @State private var unitsPerDay: Double = 10
    @State private var costPerUnit: Double = 0.5

    private var quitProgram: QuitProgram? { QuitProgram.program(id: quitProgramID) }

    private var canSave: Bool {
        if kind == .quit { return quitProgram != nil }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty && !goalDescription.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("Build a habit").tag(HabitKind.build)
                        Text("Quit something").tag(HabitKind.quit)
                    }
                    .pickerStyle(.segmented)
                }

                if kind == .quit {
                    quitSection
                } else {
                    buildSections
                }
            }
            .navigationTitle(kind == .quit ? "Quit Something" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.disabled(!canSave).fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private var quitSection: some View {
        Section("What are you quitting?") {
            Picker("Program", selection: $quitProgramID) {
                ForEach(QuitProgram.all) { program in
                    Text("\(program.emoji) \(program.title)").tag(program.id)
                }
            }
            .onChange(of: quitProgramID) { _, newValue in
                guard let program = QuitProgram.program(id: newValue) else { return }
                unitsPerDay = program.defaultUnitsPerDay
                costPerUnit = program.defaultCostPerUnit
            }
        }

        if let program = quitProgram {
            Section("Your usual amount") {
                HStack {
                    Text("\(program.unitName.capitalized) per day")
                    Spacer()
                    TextField("0", value: $unitsPerDay, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
                HStack {
                    Text(program.unitCostHint)
                    Spacer()
                    TextField("0", value: $costPerUnit, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
                Text("Used to work out what you've saved. Rough numbers are fine.")
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
            }

            if !program.safetyNote.isEmpty {
                Section {
                    Label(program.safetyNote, systemImage: "cross.case.fill")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var buildSections: some View {
        Group {
                Section("From your library") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FMTheme.Spacing.xs) {
                            ForEach(HabitCatalog.all) { blueprint in
                                Button {
                                    apply(blueprint)
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: blueprint.iconSystemName)
                                        Text(blueprint.name).font(FMTheme.Typography.footnote)
                                    }
                                    .padding(FMTheme.Spacing.sm)
                                    .background(FMTheme.Colors.forCategory(blueprint.category).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.sm, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .padding(FMTheme.Spacing.sm)

                Section("Habit") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(HabitCategory.allCases) { cat in
                            Text("\(cat.emoji) \(cat.title)").tag(cat)
                        }
                    }
                }

                Section("Goal") {
                    TextField("Goal (e.g. 20 pages)", text: $goalDescription)
                    HStack {
                        Text("Target value")
                        Spacer()
                        TextField("0", value: $goalTargetValue, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    TextField("Unit (steps, pages, ml, min)", text: $goalUnit)
                }

                Section("Verification") {
                    Picker("Method", selection: $verificationType) {
                        ForEach(VerificationType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Reminder") {
                    Toggle("Remind me", isOn: $isReminderEnabled)
                    if isReminderEnabled {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
        }
    }

    private func apply(_ blueprint: HabitBlueprint) {
        Haptics.selection()
        name = blueprint.name
        iconSystemName = blueprint.iconSystemName
        category = blueprint.category
        verificationType = blueprint.verificationType
        goalDescription = blueprint.goalDescription
        goalTargetValue = blueprint.goalTargetValue
        goalUnit = blueprint.goalUnit
    }

    private func save() {
        if kind == .quit, let program = quitProgram {
            let habit = Habit(
                name: program.id == "custom" ? "Quit \(program.title.lowercased())" : "No \(program.title.lowercased())",
                iconSystemName: "nosign",
                category: .health,
                verificationType: .manual,
                goalDescription: "Stay \(program.title.lowercased())-free",
                sortOrder: journey.habits.count,
                kind: .quit,
                quitProgramID: program.id,
                quitStartDate: .now,
                unitsPerDay: unitsPerDay,
                costPerUnit: costPerUnit
            )
            habit.journey = journey
            modelContext.insert(habit)
            try? modelContext.save()
            Haptics.notify(.success)
            dismiss()
            return
        }

        let habit = Habit(
            name: name,
            iconSystemName: iconSystemName,
            category: category,
            verificationType: verificationType,
            goalDescription: goalDescription,
            goalTargetValue: goalTargetValue,
            goalUnit: goalUnit,
            reminderTime: isReminderEnabled ? reminderTime : nil,
            isReminderEnabled: isReminderEnabled,
            sortOrder: journey.habits.count
        )
        habit.journey = journey
        modelContext.insert(habit)
        try? modelContext.save()
        Haptics.notify(.success)
        dismiss()
    }
}

#Preview {
    CreateHabitView(journey: Journey())
        .modelContainer(PreviewData.container)
}
