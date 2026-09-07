import SwiftUI
import SwiftData

/// Shown when a "start with me" link is opened.
///
/// States plainly what accepting does — pairs the two phones and sets a start date —
/// because it changes the user's journey, and an invite that quietly rewrites your data is
/// how an app loses trust in one tap.
struct PactInviteSheet: View {
    let payload: PactInvitePayload

    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Journey> { $0.isActive }) private var activeJourneys: [Journey]
    @State private var errorMessage: String?

    private var existing: Journey? { activeJourneys.first }

    private var startLabel: String {
        payload.startDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FMTheme.Spacing.lg) {
                    Text("🤝").font(.system(size: 56)).padding(.top, FMTheme.Spacing.lg)

                    VStack(spacing: FMTheme.Spacing.xs) {
                        Text("\(payload.card.displayName) wants to start with you.")
                            .font(FMTheme.Typography.title)
                            .multilineTextAlignment(.center)
                        Text("\(payload.lengthInDays) days, both starting \(startLabel).")
                            .font(FMTheme.Typography.body)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                    }

                    if let message = payload.message, !message.isEmpty {
                        Text("“\(message)”")
                            .font(FMTheme.Typography.body)
                            .italic()
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(FMTheme.Spacing.md)
                            .frame(maxWidth: .infinity)
                            .background(FMTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                        Text("Accepting will:")
                            .font(FMTheme.Typography.headline)
                        bullet("Add \(payload.card.displayName) as a friend on this phone.")
                        if existing == nil {
                            bullet("Start your \(payload.lengthInDays) days on \(startLabel).")
                        } else {
                            bullet("Leave your current journey exactly as it is — we won't renumber days you've already done.")
                        }
                        bullet("Send nothing anywhere. There's no server in this.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(FMTheme.Spacing.md)
                    .background(FMTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))

                    FMPrimaryButton(title: "Start together", icon: "checkmark") { accept() }
                    Button("Not now") { dismiss() }
                        .font(FMTheme.Typography.caption)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Couldn't accept", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FMTheme.Colors.accent)
                .padding(.top, 4)
            Text(text)
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textSecondary)
        }
    }

    private func accept() {
        do {
            try PactService(modelContext: modelContext).accept(
                payload,
                ownPeerID: services.peerIdentity.peerID,
                existingJourney: existing
            )
            Haptics.notify(.success)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
