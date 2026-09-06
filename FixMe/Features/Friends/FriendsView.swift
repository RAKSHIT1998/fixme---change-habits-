import SwiftUI
import SwiftData

/// Friends and their verified updates. No accounts, no server — every entry here came
/// from a device you paired with directly.
struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services

    @Query(sort: \Friend.displayName) private var friends: [Friend]
    @Query(sort: \FriendUpdate.createdAt, order: .reverse) private var updates: [FriendUpdate]
    @Query(filter: #Predicate<Journey> { $0.isActive }) private var journeys: [Journey]

    @State private var showAddFriend = false
    @State private var showShareProgress = false
    @State private var friendToRemove: Friend?
    @State private var banner: String?

    private var store: FriendStore { services.makeFriendStore(modelContext) }

    var body: some View {
        Group {
            if friends.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add a friend", systemImage: "person.badge.plus") { showAddFriend = true }
                    Button("Share my progress", systemImage: "paperplane") { showShareProgress = true }
                } label: {
                    Image(systemName: "person.2.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showAddFriend) { AddFriendView() }
        .sheet(isPresented: $showShareProgress) {
            ShareProgressView(journey: journeys.first)
        }
        .confirmationDialog(
            "Remove \(friendToRemove?.displayName ?? "")?",
            isPresented: Binding(get: { friendToRemove != nil }, set: { if !$0 { friendToRemove = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let friendToRemove { store.remove(friendToRemove) }
                friendToRemove = nil
            }
            Button("Cancel", role: .cancel) { friendToRemove = nil }
        } message: {
            Text("Their updates are deleted from this device. They keep whatever you already sent them.")
        }
        .onChange(of: services.nearby.inbox.count) { _, _ in drainInbox() }
        .task { drainInbox() }
    }

    // MARK: - Sections

    private var list: some View {
        ScrollView {
            VStack(spacing: FMTheme.Spacing.sm) {
                if let banner {
                    Text(banner)
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.success)
                        .frame(maxWidth: .infinity)
                        .padding(FMTheme.Spacing.sm)
                        .background(FMTheme.Colors.success.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FMTheme.Spacing.sm) {
                        ForEach(friends) { friend in
                            FriendChip(friend: friend) { friendToRemove = friend }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                if updates.isEmpty {
                    VStack(spacing: FMTheme.Spacing.xs) {
                        Text("📭").font(.system(size: 32))
                        Text("No updates yet.")
                            .font(FMTheme.Typography.subheadline)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                        Text("Updates arrive when you're near each other with the app open, or when they send you a link.")
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, FMTheme.Spacing.xl)
                } else {
                    ForEach(updates) { update in
                        FriendUpdateCard(update: update)
                    }
                }

                transportNotice
            }
            .padding(FMTheme.Spacing.md)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No friends yet", systemImage: "person.2")
        } description: {
            Text("Pair directly with someone's phone — over Wi-Fi and Bluetooth when you're together, or with an invite link at any distance. No account, no server.")
        } actions: {
            Button("Add a friend") { showAddFriend = true }
                .buttonStyle(.borderedProminent)
                .tint(FMTheme.Colors.accent)
        }
    }

    private var transportNotice: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
            Text("Peer-to-peer: nothing is uploaded and no one can push to you. Updates arrive when you're nearby with the app open, or when a friend sends you a link — so open this now and then.")
        }
        .font(.system(size: 11))
        .foregroundStyle(FMTheme.Colors.textTertiary)
        .padding(.top, FMTheme.Spacing.sm)
    }

    // MARK: - Inbox

    /// Moves envelopes received over a live nearby session into storage, verifying each.
    private func drainInbox() {
        let pending = services.nearby.inbox
        guard !pending.isEmpty else { return }
        var added = 0
        for envelope in pending {
            if (try? store.receive(envelope)) != nil { added += 1 }
        }
        services.nearby.clearInbox()
        if added > 0 {
            Haptics.notify(.success)
            banner = "\(added) new update\(added == 1 ? "" : "s") received."
        }
    }
}

// MARK: - Components

private struct FriendChip: View {
    let friend: Friend
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(FMTheme.Colors.accent.opacity(0.18))
                .frame(width: 46, height: 46)
                .overlay(
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(FMTheme.Typography.headline)
                        .foregroundStyle(FMTheme.Colors.accent)
                )
                .overlay(alignment: .bottomTrailing) {
                    if friend.pairedNearby {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(FMTheme.Colors.success)
                    }
                }
            Text(friend.displayName)
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textPrimary)
                .lineLimit(1)
        }
        .frame(width: 72)
        .contextMenu {
            Button("Remove friend", systemImage: "trash", role: .destructive, action: onRemove)
        }
        .accessibilityLabel("\(friend.displayName)\(friend.pairedNearby ? ", paired in person" : "")")
    }
}

private struct FriendUpdateCard: View {
    let update: FriendUpdate

    var body: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
            HStack(spacing: FMTheme.Spacing.sm) {
                Circle()
                    .fill(FMTheme.Colors.accent.opacity(0.18))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text(String((update.friend?.displayName ?? "?").prefix(1)).uppercased())
                            .font(FMTheme.Typography.caption)
                            .foregroundStyle(FMTheme.Colors.accent)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(update.friend?.displayName ?? "Unknown")
                        .font(FMTheme.Typography.headline)
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    HStack(spacing: 4) {
                        Text("Day \(update.dayNumber) · \(update.completionPercent)%")
                        if update.streak > 0 { Text("· 🔥\(update.streak)") }
                    }
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(update.createdAt, style: .date)
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textTertiary)
                    // Everything shown here passed signature verification on arrival.
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(FMTheme.Colors.success)
                }
            }

            if let message = update.message, !message.isEmpty {
                Text(message)
                    .font(FMTheme.Typography.body)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let cleanDays = update.cleanDays {
                Text("🌱 \(cleanDays) days clean")
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.success)
            }

            if !update.habitNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(update.habitNames, id: \.self) { name in
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                                Text(name).font(FMTheme.Typography.footnote)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(FMTheme.Colors.success.opacity(0.12))
                            .foregroundStyle(FMTheme.Colors.success)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
    }
}

#Preview {
    NavigationStack { FriendsView() }
        .modelContainer(PreviewData.container)
}
