import SwiftUI
import SwiftData

/// Starting a challenge.
///
/// The terms are deliberately unforgiving, so the screen's job is to make sure nobody
/// agrees to them by accident: the rule is stated in full, the confirm toggle is explicit,
/// and the button doesn't enable until it's on. A commitment device that someone can enter
/// without noticing isn't a commitment device — it's a trap.
struct StakeSetupView: View {
    let journey: Journey

    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Friend.displayName) private var friends: [Friend]

    @State private var stakeAmount: Double = 50
    @State private var stakeHolder = ""
    @State private var referee: Friend?
    @State private var acceptedTerms = false

    private var habitCount: Int { journey.habits.filter { !$0.isQuit }.count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                        Text("Put something on it.")
                            .font(FMTheme.Typography.title)
                        Text("People finish far more often when failing costs them something they can name. Pick a number that would genuinely annoy you to lose.")
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                    }
                    .padding(.vertical, FMTheme.Spacing.xs)
                }

                Section("Your stake") {
                    HStack {
                        Text(formatted(stakeAmount))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(FMTheme.Colors.accent)
                        Spacer()
                    }
                    Slider(value: $stakeAmount, in: 5...500, step: 5)
                    TextField("Who collects if you fail? (a friend, a charity)", text: $stakeHolder)
                        .textInputAutocapitalization(.words)
                }

                if !friends.isEmpty {
                    Section("Referee") {
                        Picker("Referee", selection: $referee) {
                            Text("No referee").tag(Friend?.none)
                            ForEach(friends) { friend in
                                Text(friend.displayName).tag(Friend?.some(friend))
                            }
                        }
                        Text("A referee is someone who knows the deal. The app doesn't message them for you — telling someone is the point.")
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                    }
                }

                Section("The rules") {
                    rule("Every habit, every day, for \(journey.lengthInDays) days.",
                         detail: habitCount == 0
                            ? "Add at least one habit before starting."
                            : "All \(habitCount) of your current habits count. Adding one later counts from that day on.")
                    rule("Miss a single day and it's over.",
                         detail: "No freezes, no repair, no exceptions. That's what makes it work.")
                    rule("Quit habits count as kept unless you log a relapse.",
                         detail: "Same as everywhere else in the app.")
                    rule("The app never touches your money.",
                         detail: "It records what you pledged and holds you to it. Settling up is between you and whoever's collecting.")
                }

                Section {
                    Toggle(isOn: $acceptedTerms) {
                        Text("I understand that missing one day ends this challenge, and that Fix Me does not hold or refund my stake.")
                            .font(FMTheme.Typography.footnote)
                    }
                }

                Section {
                    Button("Lock in \(formatted(stakeAmount))") { start() }
                        .fontWeight(.semibold)
                        .disabled(!canStart)
                }
            }
            .navigationTitle("New challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var canStart: Bool { acceptedTerms && habitCount > 0 }

    private func rule(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(FMTheme.Typography.subheadline)
            Text(detail)
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textSecondary)
        }
        .padding(.vertical, 2)
    }

    private func formatted(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }

    private func start() {
        let service = StakeService(modelContext: modelContext)
        let challenge = service.start(
            journey: journey,
            stakeAmount: stakeAmount,
            stakeHolder: stakeHolder.trimmingCharacters(in: .whitespacesAndNewlines),
            referee: referee
        )
        service.refresh(challenge, habits: journey.habits)
        Haptics.notify(.success)
        dismiss()
    }
}

#Preview {
    StakeSetupView(journey: Journey())
        .modelContainer(PreviewData.container)
}
