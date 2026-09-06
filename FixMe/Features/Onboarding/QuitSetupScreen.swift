import SwiftUI

/// Asks — without assuming — whether the user has anything they want to stop.
///
/// Framed as an opt-in question rather than a checklist of vices: most people have none
/// of these, and being asked "which of your addictions?" on day one is a bad first
/// impression. "None of these" is a first-class answer, not a skip link.
struct QuitSetupScreen: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.lg) {
            OnboardingHeader(
                title: "Anything you want to stop?",
                subtitle: "Optional. Quitting gets its own counter — clean time, money saved, and what your body's doing about it."
            )

            ScrollView {
                VStack(spacing: FMTheme.Spacing.sm) {
                    ForEach(QuitProgram.all) { program in
                        QuitProgramRow(
                            program: program,
                            isSelected: viewModel.selectedQuitProgramIDs.contains(program.id),
                            unitsPerDay: viewModel.quitUnitsPerDay[program.id] ?? program.defaultUnitsPerDay,
                            costPerUnit: viewModel.quitCostPerUnit[program.id] ?? program.defaultCostPerUnit,
                            onToggle: { viewModel.toggleQuitProgram(program) },
                            onUnitsChange: { viewModel.quitUnitsPerDay[program.id] = $0 },
                            onCostChange: { viewModel.quitCostPerUnit[program.id] = $0 }
                        )
                    }

                    NoneOfTheseRow(isSelected: viewModel.selectedQuitProgramIDs.isEmpty) {
                        viewModel.clearQuitPrograms()
                    }
                }
            }

            FMPrimaryButton(title: "Continue", icon: "arrow.right") {
                viewModel.advance()
            }
        }
        .padding(FMTheme.Spacing.lg)
    }
}

private struct QuitProgramRow: View {
    let program: QuitProgram
    let isSelected: Bool
    let unitsPerDay: Double
    let costPerUnit: Double
    let onToggle: () -> Void
    let onUnitsChange: (Double) -> Void
    let onCostChange: (Double) -> Void

    var body: some View {
        VStack(spacing: FMTheme.Spacing.sm) {
            Button(action: onToggle) {
                HStack(spacing: FMTheme.Spacing.sm) {
                    Text(program.emoji).font(.system(size: 26))
                    Text(program.title)
                        .font(FMTheme.Typography.headline)
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? FMTheme.Colors.accent : FMTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if isSelected {
                // Asked here because "money saved" is the number people come back for,
                // and it's meaningless without their actual habit and prices.
                VStack(spacing: FMTheme.Spacing.xs) {
                    StepperRow(
                        label: "\(program.unitName.capitalized) per day",
                        value: unitsPerDay,
                        step: unitsPerDay < 2 ? 0.5 : 1,
                        format: unitsPerDay < 2 ? "%.1f" : "%.0f",
                        onChange: onUnitsChange
                    )
                    StepperRow(
                        label: program.unitCostHint,
                        value: costPerUnit,
                        step: 0.5,
                        format: "%.2f",
                        onChange: onCostChange
                    )

                    if !program.safetyNote.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "cross.case.fill")
                            Text(program.safetyNote)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                        .padding(FMTheme.Spacing.sm)
                        .background(FMTheme.Colors.warning.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.sm, style: .continuous))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(FMTheme.Spacing.sm)
        .background(isSelected ? FMTheme.Colors.accent.opacity(0.08) : FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
        .animation(FMTheme.Motion.snappy, value: isSelected)
    }
}

private struct StepperRow: View {
    let label: String
    let value: Double
    let step: Double
    let format: String
    let onChange: (Double) -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textSecondary)
            Spacer(minLength: FMTheme.Spacing.xs)
            Text(String(format: format, value))
                .font(FMTheme.Typography.subheadline)
                .monospacedDigit()
                .foregroundStyle(FMTheme.Colors.textPrimary)
            Stepper("", value: Binding(get: { value }, set: onChange), in: 0...100, step: step)
                .labelsHidden()
        }
    }
}

private struct NoneOfTheseRow: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FMTheme.Spacing.sm) {
                Text("👍").font(.system(size: 26))
                Text("None of these")
                    .font(FMTheme.Typography.headline)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? FMTheme.Colors.accent : FMTheme.Colors.textTertiary)
            }
            .padding(FMTheme.Spacing.sm)
            .background(FMTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuitSetupScreen(viewModel: OnboardingViewModel())
}
