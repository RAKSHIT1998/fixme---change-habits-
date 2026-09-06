import SwiftUI
import SwiftData

/// Composes a signed progress update and sends it — over a live nearby session if one is
/// open, otherwise as a `fixme://` link through any messaging app.
///
/// The user picks exactly what goes in. There is no background sync: with no server, a
/// friend only ever sees what was deliberately sent.
struct ShareProgressView: View {
    let journey: Journey?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var includeHabits = true
    @State private var includeStreak = true
    @State private var includeCleanTime = true
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var sentNearby = false
    @State private var errorText: String?

    private var habits: [Habit] {
        (journey?.habits ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var completedToday: [Habit] {
        habits.filter { habit in
            habit.isQuit ? !habit.relapsed(on: .now) : (habit.completion(on: .now)?.state.isDone ?? false)
        }
    }

    private var completionPercent: Int {
        guard !habits.isEmpty else { return 0 }
        return Int((Double(completedToday.count) / Double(habits.count) * 100).rounded())
    }

    private var cleanDays: Int? {
        guard includeCleanTime,
              let quit = habits.first(where: { $0.isQuit && $0.quitStartDate != nil })
        else { return nil }
        return Int(QuitProgressCalculator.cleanTime(for: quit) / 86_400)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FMTheme.Spacing.lg) {
                    preview

                    VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                        Text("Add a note")
                            .font(FMTheme.Typography.headline)
                            .foregroundStyle(FMTheme.Colors.textPrimary)
                        TextField("Optional", text: $message, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(FMTheme.Spacing.sm)
                            .background(FMTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                        Text("What to include")
                            .font(FMTheme.Typography.headline)
                            .foregroundStyle(FMTheme.Colors.textPrimary)
                        Toggle("Habit names", isOn: $includeHabits).tint(FMTheme.Colors.accent)
                        Toggle("Streak", isOn: $includeStreak).tint(FMTheme.Colors.accent)
                        if habits.contains(where: \.isQuit) {
                            Toggle("Days clean", isOn: $includeCleanTime).tint(FMTheme.Colors.accent)
                        }
                    }

                    if case .connected(let name) = services.nearby.state {
                        FMPrimaryButton(
                            title: sentNearby ? "Sent to \(name) ✓" : "Send to \(name)",
                            icon: "antenna.radiowaves.left.and.right"
                        ) {
                            sendNearby()
                        }
                    }

                    FMSecondaryButton(title: "Send as a link") { makeLink() }

                    if let errorText {
                        Text(errorText)
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.danger)
                    }

                    Text("Only your friends' devices can read this, and only the fields above are included. Nothing is uploaded anywhere.")
                        .font(.system(size: 11))
                        .foregroundStyle(FMTheme.Colors.textTertiary)
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Share Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareURL {
                    ActivityShareSheet(items: [shareText(shareURL), shareURL])
                }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DAY \(journey?.dayNumber() ?? 0) · \(completionPercent)%")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(FMTheme.Colors.accent)
            if includeHabits && !completedToday.isEmpty {
                Text(completedToday.map(\.name).joined(separator: " · "))
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let cleanDays {
                Text("\(cleanDays) days clean")
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.success)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
    }

    // MARK: - Building

    private func makePayload() -> ProgressUpdatePayload {
        ProgressUpdatePayload(
            displayName: services.peerIdentity.displayName,
            dayNumber: journey?.dayNumber() ?? 0,
            totalDays: journey?.lengthInDays ?? 90,
            completionPercent: completionPercent,
            streak: includeStreak ? (habits.map { $0.currentStreak() }.max() ?? 0) : 0,
            habitNames: includeHabits ? completedToday.map(\.name) : [],
            message: message.isEmpty ? nil : message,
            cleanDays: cleanDays
        )
    }

    private func makeEnvelope() throws -> SignedEnvelope {
        try SignedEnvelope.make(
            makePayload(),
            kind: .progressUpdate,
            identity: services.peerIdentity.identity,
            sign: { try services.peerIdentity.sign($0) }
        )
    }

    private func sendNearby() {
        do {
            try services.nearby.send(try makeEnvelope())
            sentNearby = true
            Haptics.notify(.success)
        } catch {
            errorText = "Couldn't send that: \(error.localizedDescription)"
        }
    }

    private func makeLink() {
        do {
            shareURL = InviteLink.web(for: try PeerLink.updateURL(for: try makeEnvelope()))
            showShareSheet = true
        } catch {
            errorText = "Couldn't build that link: \(error.localizedDescription)"
        }
    }

    private func shareText(_ url: URL) -> String {
        "Day \(journey?.dayNumber() ?? 0) — \(completionPercent)% done.\n\n\(url.absoluteString)"
    }
}

#Preview {
    ShareProgressView(journey: Journey())
        .modelContainer(PreviewData.container)
}
