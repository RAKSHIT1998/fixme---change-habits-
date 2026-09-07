import SwiftUI
import SwiftData

/// "We both start Monday."
///
/// The referral screen asks someone to join sometime, which is a favour they can defer
/// forever. This asks for a specific day, which is an appointment — and the invite is
/// functional rather than altruistic, because a shared start doesn't exist unless the
/// other person actually turns up.
struct StartTogetherView: View {
    let journey: Journey?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var startDate = Calendar.current.startOfDay(for: .now)
    @State private var note = ""
    @State private var shareURL: URL?
    @State private var errorMessage: String?

    private var range: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: .now)
        let last = Calendar.current.date(byAdding: .day, value: PactService.maxDaysAhead, to: today) ?? today
        return today...last
    }

    private var lengthInDays: Int { journey?.lengthInDays ?? 90 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                        Text("Start together.")
                            .font(FMTheme.Typography.title)
                        Text("Pick a day and send it. You'll both be on the same day number for the whole \(lengthInDays) — which is the part that makes people actually show up.")
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                    }
                    .padding(.vertical, FMTheme.Spacing.xs)
                }

                Section("The day") {
                    DatePicker("We both start", selection: $startDate, in: range, displayedComponents: .date)
                    Text(dayLabel)
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }

                Section("Add a note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    Button("Send the invite") { makeInvite() }
                        .fontWeight(.semibold)
                } footer: {
                    Text("The link pairs your phones and sets their start date. If they're already mid-journey, their run is left alone — we'd never renumber days someone already did.")
                }
            }
            .navigationTitle("Start together")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .sheet(item: Binding(
                get: { shareURL.map(ShareableURL.init) },
                set: { shareURL = $0?.url }
            )) { shareable in
                ActivityShareSheet(items: [inviteText(url: shareable.url), shareable.url])
            }
            .alert("Couldn't create the invite", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var dayLabel: String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: startDate)
        ).day ?? 0
        switch days {
        case 0: return "Starting today."
        case 1: return "Starting tomorrow."
        default: return "Starting in \(days) days."
        }
    }

    private func inviteText(url: URL) -> String {
        let day = startDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
        var lines = ["I'm starting \(lengthInDays) days on \(day). Do it with me?"]
        if !note.isEmpty { lines.append(note) }
        lines.append(url.absoluteString)
        return lines.joined(separator: "\n\n")
    }

    private func makeInvite() {
        let service = PactService(modelContext: modelContext)
        let card = services.peerIdentity.identity.card
        let payload = service.invitePayload(
            card: card,
            startDate: startDate,
            lengthInDays: lengthInDays,
            message: note
        )
        do {
            // Sent as an https link so it's tappable in every messenger and useful to
            // someone who doesn't have the app yet.
            shareURL = InviteLink.web(for: try PeerLink.pactURL(for: payload))
            services.analytics.track(.referralShared)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShareableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

#Preview {
    StartTogetherView(journey: Journey())
        .modelContainer(PreviewData.container)
}
