import SwiftUI
import SwiftData
import MultipeerConnectivity
import ContactsUI

/// Pairing, two ways — both without a server.
///
/// **Nearby** forms a direct encrypted link over Wi-Fi/Bluetooth when both people are in
/// the same room. **Invite link** works at any distance by sending a signed `fixme://`
/// link through whatever messaging app they already use.
struct AddFriendView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .nearby
    @State private var showShareSheet = false
    @State private var showContactPicker = false
    @State private var pastedLink = ""
    @State private var message: String?
    @State private var isError = false

    enum Mode: String, CaseIterable, Identifiable {
        case nearby = "Nearby", link = "Invite link"
        var id: String { rawValue }
    }

    private var nearby: NearbyPeerService { services.nearby }
    private var store: FriendStore { services.makeFriendStore(modelContext) }

    var body: some View {
        NavigationStack {
            VStack(spacing: FMTheme.Spacing.md) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, FMTheme.Spacing.lg)

                ScrollView {
                    VStack(spacing: FMTheme.Spacing.md) {
                        switch mode {
                        case .nearby: nearbySection
                        case .link: linkSection
                        }

                        if let message {
                            Text(message)
                                .font(FMTheme.Typography.footnote)
                                .foregroundStyle(isError ? FMTheme.Colors.danger : FMTheme.Colors.success)
                                .multilineTextAlignment(.center)
                        }

                        decentralisedNotice
                    }
                    .padding(FMTheme.Spacing.lg)
                }
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Add a Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            }
            .onAppear { nearby.start(identity: services.peerIdentity.identity) }
            .onDisappear { nearby.stop() }
            .onChange(of: nearby.pendingCards) { _, cards in
                // Cards arriving over a live session still require confirmation below.
                if !cards.isEmpty { Haptics.notify(.warning) }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = try? PeerLink.inviteURL(for: services.peerIdentity.identity.card) {
                    ActivityShareSheet(items: [inviteText(url: url), url])
                }
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView { _ in
                    // The picker hands back one contact without granting address book
                    // access. We only use it to start a message — no contact is stored.
                    showContactPicker = false
                    showShareSheet = true
                }
            }
        }
    }

    // MARK: - Nearby

    private var nearbySection: some View {
        VStack(spacing: FMTheme.Spacing.md) {
            statusRow

            if !nearby.pendingCards.isEmpty {
                VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                    Text("Confirm it's them")
                        .font(FMTheme.Typography.headline)
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    Text("Only add someone whose phone is actually in front of you.")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)

                    ForEach(nearby.pendingCards, id: \.peerID) { card in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(card.displayName).font(FMTheme.Typography.headline)
                                Text(shortFingerprint(card))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(FMTheme.Colors.textTertiary)
                            }
                            Spacer(minLength: 0)
                            Button("Add") { add(card, nearby: true) }
                                .buttonStyle(.borderedProminent)
                                .tint(FMTheme.Colors.accent)
                        }
                        .padding(FMTheme.Spacing.sm)
                        .background(FMTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                    }
                }
            }

            if nearby.discoveredPeers.isEmpty {
                VStack(spacing: FMTheme.Spacing.xs) {
                    ProgressView()
                    Text("Looking for friends nearby…")
                        .font(FMTheme.Typography.subheadline)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                    Text("Both phones need Fix Me open on this screen, on the same Wi-Fi or with Bluetooth on.")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, FMTheme.Spacing.lg)
            } else {
                ForEach(nearby.discoveredPeers, id: \.self) { peer in
                    Button {
                        nearby.invite(peer)
                        nearby.sendIdentityCard { try services.peerIdentity.sign($0) }
                    } label: {
                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundStyle(FMTheme.Colors.accent)
                            Text(peer.displayName).foregroundStyle(FMTheme.Colors.textPrimary)
                            Spacer(minLength: 0)
                            Text("Connect").font(FMTheme.Typography.footnote)
                                .foregroundStyle(FMTheme.Colors.accent)
                        }
                        .padding(FMTheme.Spacing.sm)
                        .background(FMTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = nearby.lastError {
                Text(error)
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.warning)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textSecondary)
        }
    }

    private var statusColor: Color {
        switch nearby.state {
        case .connected: return FMTheme.Colors.success
        case .failed: return FMTheme.Colors.danger
        case .idle: return FMTheme.Colors.textTertiary
        default: return FMTheme.Colors.warning
        }
    }

    private var statusText: String {
        switch nearby.state {
        case .idle: return "Not searching"
        case .browsing: return "Discoverable as \(services.peerIdentity.displayName)"
        case .connecting(let name): return "Connecting to \(name)…"
        case .connected(let name): return "Connected to \(name)"
        case .failed(let reason): return reason
        }
    }

    // MARK: - Link

    private var linkSection: some View {
        VStack(spacing: FMTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                Text("Send your invite")
                    .font(FMTheme.Typography.headline)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
                Text("Works at any distance. The link carries your name and public key — nothing else.")
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)

                FMPrimaryButton(title: "Share invite link", icon: "square.and.arrow.up") {
                    showShareSheet = true
                }
                Button {
                    showContactPicker = true
                } label: {
                    Label("Pick from Contacts", systemImage: "person.crop.circle")
                        .font(FMTheme.Typography.subheadline)
                        .foregroundStyle(FMTheme.Colors.accent)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                Text("Paste theirs")
                    .font(FMTheme.Typography.headline)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
                TextField("fixme://add-friend?d=…", text: $pastedLink, axis: .vertical)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(FMTheme.Spacing.sm)
                    .background(FMTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))

                FMSecondaryButton(title: "Add from link") { importPastedLink() }
            }
        }
    }

    private var decentralisedNotice: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
            Text("Friends are stored only on your two devices. There's no account, no server and no database — updates travel directly between phones, or inside a link you send yourself.")
        }
        .font(.system(size: 11))
        .foregroundStyle(FMTheme.Colors.textTertiary)
        .padding(.top, FMTheme.Spacing.sm)
    }

    // MARK: - Actions

    private func inviteText(url: URL) -> String {
        """
        Add me on Fix Me so we can keep each other honest for 90 days.

        \(url.absoluteString)
        """
    }

    /// A short fingerprint of the key, so two people can eyeball that they paired with
    /// each other and not someone else in range.
    private func shortFingerprint(_ card: IdentityCard) -> String {
        card.publicKeyData.prefix(4).map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private func importPastedLink() {
        let trimmed = pastedLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            show("That doesn't look like a link.", error: true); return
        }
        do {
            guard case .invite(let card) = try PeerLink.parse(url) else {
                show("That's a progress update, not an invite.", error: true); return
            }
            add(card, nearby: false)
            pastedLink = ""
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    private func add(_ card: IdentityCard, nearby isNearby: Bool) {
        do {
            let friend = try store.addFriend(
                from: card,
                ownPeerID: services.peerIdentity.peerID,
                nearby: isNearby
            )
            Haptics.notify(.success)
            show("\(friend.displayName) added.", error: false)
            self.nearby.clearPendingCards()
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    private func show(_ text: String, error: Bool) {
        message = text
        isError = error
    }
}

/// Wraps `CNContactPickerViewController`.
///
/// The picker runs out of process, so it needs **no Contacts permission** and the app
/// never sees the address book — only the single contact the user taps. With no server
/// there's no way to know which contacts use Fix Me anyway, so this exists purely to
/// start a message.
struct ContactPickerView: UIViewControllerRepresentable {
    let onPick: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (CNContact) -> Void
        init(onPick: @escaping (CNContact) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPick(contact)
        }
    }
}

#Preview {
    AddFriendView().modelContainer(PreviewData.container)
}
