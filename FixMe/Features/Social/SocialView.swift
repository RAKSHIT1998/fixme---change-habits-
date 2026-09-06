import SwiftUI
import SwiftData

/// The user's progress wall.
///
/// Previously this screen had a Following/Friends/Discover picker that filtered nothing
/// and a feed nothing could ever post to. Both are fixed: every filter here is backed by
/// real data, and posts are created from the recap flow or the compose button.
///
/// What it still can't do is show other people — that needs a backend. Rather than fake a
/// community, the screen reads `SocialService.supportsOtherPeople` and describes itself
/// accurately, so the copy corrects itself the day a real implementation lands.
struct SocialView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState

    private var social: SocialService { services.makeSocial(modelContext) }

    @Query(sort: \SocialPost.createdAt, order: .reverse) private var allPosts: [SocialPost]
    @Query private var journeys: [Journey]

    @State private var section: Section = .wall
    @State private var filter: FeedFilter = .all

    enum Section: String, CaseIterable, Identifiable {
        case wall = "My Wall", friends = "Friends"
        var id: String { rawValue }
    }
    @State private var showCompose = false
    @State private var postToShare: SocialPost?

    private var posts: [SocialPost] { allPosts.filter(filter.matches) }
    private var activeJourney: Journey? { journeys.first(where: \.isActive) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, FMTheme.Spacing.md)
                .padding(.bottom, FMTheme.Spacing.xs)

                switch section {
                case .wall:
                    if allPosts.isEmpty { emptyState } else { feed }
                case .friends:
                    FriendsView()
                }
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if section == .wall {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCompose = true } label: { Image(systemName: "square.and.pencil") }
                    }
                }
            }
            .onAppear {
                if appState.initialSocialSection == "friends" { section = .friends }
            }
            .sheet(isPresented: $showCompose) {
                ComposePostView(initialDraft: draftFromToday())
            }
            .sheet(item: $postToShare) { post in
                if let journey = activeJourney {
                    ShareTemplateView(
                        journey: journey,
                        dayNumber: post.dayNumber,
                        completionPercent: post.completionPercent
                    )
                }
            }
        }
    }

    // MARK: - Feed

    private var feed: some View {
        ScrollView {
            VStack(spacing: FMTheme.Spacing.sm) {
                filterBar

                if posts.isEmpty {
                    // The wall has posts, just none matching this filter.
                    VStack(spacing: FMTheme.Spacing.xs) {
                        Text(filter == .milestones ? "🏆" : "📷").font(.system(size: 36))
                        Text(filter == .milestones
                             ? "No milestone posts yet."
                             : "No posts with photos yet.")
                            .font(FMTheme.Typography.subheadline)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                    }
                    .padding(.vertical, FMTheme.Spacing.xxl)
                } else {
                    ForEach(posts) { post in
                        SocialPostCard(
                            post: post,
                            onReact: { social.react($0, to: post) },
                            onShare: { postToShare = post },
                            onDelete: { withAnimation { social.delete(post) } }
                        )
                    }
                }

                if !social.supportsOtherPeople {
                    localOnlyNotice
                }
            }
            .padding(FMTheme.Spacing.md)
        }
    }

    private var filterBar: some View {
        Picker("Filter", selection: $filter) {
            ForEach(FeedFilter.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: filter) { _, _ in Haptics.selection() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your wall is empty", systemImage: "square.stack")
        } description: {
            Text("Post a day you're proud of. It's a record you can scroll back through when a bad week makes it feel like nothing's changed.")
        } actions: {
            Button("Write your first post") { showCompose = true }
                .buttonStyle(.borderedProminent)
                .tint(FMTheme.Colors.accent)
        }
    }

    /// Honest about what this feature is today.
    private var localOnlyNotice: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "iphone")
            Text("Your wall stays on this device — nothing is uploaded. To share progress with someone, add them under Friends and send it phone-to-phone.")
        }
        .font(.system(size: 11))
        .foregroundStyle(FMTheme.Colors.textTertiary)
        .padding(.top, FMTheme.Spacing.sm)
        .padding(.horizontal, FMTheme.Spacing.xs)
    }

    // MARK: - Draft

    /// Pre-fills a post from today's real progress so the stats aren't invented.
    private func draftFromToday() -> SocialPostDraft {
        guard let journey = activeJourney else {
            return SocialPostDraft(kind: .note)
        }
        let habits = journey.habits.sorted { $0.sortOrder < $1.sortOrder }
        let done = habits.filter { habit in
            habit.isQuit
                ? !habit.relapsed(on: .now)
                : (habit.completion(on: .now)?.state.isDone ?? false)
        }
        let percent = habits.isEmpty ? 0 : Int((Double(done.count) / Double(habits.count) * 100).rounded())

        return SocialPostDraft(
            kind: .dayRecap,
            dayNumber: journey.dayNumber(),
            completionPercent: percent,
            streak: habits.map { $0.currentStreak() }.max() ?? 0,
            habitNames: done.map(\.name)
        )
    }
}

// MARK: - Post card

private struct SocialPostCard: View {
    @Bindable var post: SocialPost
    let onReact: (SocialReaction) -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
            header

            if let name = post.imageFileName, let image = ImageStore.load(name) {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
            }

            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(FMTheme.Typography.body)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !post.habitNames.isEmpty {
                FlowChips(items: post.habitNames)
            }

            HStack(spacing: FMTheme.Spacing.xs) {
                ForEach(SocialReaction.allCases) { reaction in
                    ReactionButton(
                        reaction: reaction,
                        count: count(for: reaction)
                    ) {
                        Haptics.impact(.light)
                        onReact(reaction)
                    }
                }
                Spacer(minLength: 0)
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                        .padding(8)
                        .background(FMTheme.Colors.surfaceElevated, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
        .contextMenu {
            Button("Share", systemImage: "square.and.arrow.up", action: onShare)
            Button("Delete", systemImage: "trash", role: .destructive) { showDeleteConfirm = true }
        }
        .confirmationDialog("Delete this post?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the post and any photo attached to it.")
        }
    }

    private var header: some View {
        HStack(spacing: FMTheme.Spacing.sm) {
            Circle()
                .fill(FMTheme.Colors.accent.opacity(0.2))
                .frame(width: 34, height: 34)
                .overlay(
                    Text(String(post.authorName.prefix(1)))
                        .font(FMTheme.Typography.caption)
                        .foregroundStyle(FMTheme.Colors.accent)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(post.authorName)
                    .font(FMTheme.Typography.headline)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: post.kind.symbol)
                    Text(post.kind == .milestone
                         ? (post.milestoneTitle ?? "Milestone")
                         : "Day \(post.dayNumber) · \(post.completionPercent)%")
                    if post.streak > 0 {
                        Text("· 🔥\(post.streak)")
                    }
                }
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(post.createdAt, style: .date)
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textTertiary)
                Image(systemName: post.privacyLevel == .privateOnly ? "lock.fill" : "person.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(FMTheme.Colors.textTertiary)
            }
        }
    }

    private func count(for reaction: SocialReaction) -> Int {
        switch reaction {
        case .heart: return post.heartCount
        case .fire: return post.fireCount
        case .clap: return post.clapCount
        }
    }
}

private struct ReactionButton: View {
    let reaction: SocialReaction
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(reaction.emoji)
                if count > 0 {
                    Text("\(count)")
                        .font(FMTheme.Typography.footnote)
                        .monospacedDigit()
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(FMTheme.Colors.surfaceElevated)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(reaction.rawValue), \(count)")
    }
}

/// Simple wrapping chip row for the habits captured in a post.
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                        Text(item).font(FMTheme.Typography.footnote)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(FMTheme.Colors.success.opacity(0.12))
                    .foregroundStyle(FMTheme.Colors.success)
                    .clipShape(Capsule())
                }
            }
        }
    }
}

#Preview {
    SocialView().modelContainer(PreviewData.container)
}
