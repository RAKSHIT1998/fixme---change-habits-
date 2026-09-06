import SwiftUI
import SwiftData
import PhotosUI

/// Creates a post. This is what the Social tab was missing entirely — without it the feed
/// had no way to ever contain anything.
///
/// Pre-fills from the user's actual day so posting is one tap from the recap screen, and
/// the stats on a post are real rather than typed in.
struct ComposePostView: View {
    /// Pre-filled from the caller (day recap, milestone) or empty for a free-form note.
    let initialDraft: SocialPostDraft
    var onPosted: ((SocialPost) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services

    private var social: SocialService { services.makeSocial(modelContext) }
    @Query private var users: [User]

    @State private var caption: String
    @State private var privacy: PrivacyLevel
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var errorMessage: String?

    init(initialDraft: SocialPostDraft, onPosted: ((SocialPost) -> Void)? = nil) {
        self.initialDraft = initialDraft
        self.onPosted = onPosted
        _caption = State(initialValue: initialDraft.caption)
        _privacy = State(initialValue: initialDraft.privacyLevel)
        _image = State(initialValue: initialDraft.image)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FMTheme.Spacing.lg) {
                    statsPreview

                    VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                        Text("Say something")
                            .font(FMTheme.Typography.headline)
                            .foregroundStyle(FMTheme.Colors.textPrimary)
                        TextField("Still showing up.", text: $caption, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(FMTheme.Spacing.sm)
                            .background(FMTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                    }

                    photoPicker
                    privacyPicker
                    storageNotice

                    if let errorMessage {
                        Text(errorMessage)
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.danger)
                    }
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") { post() }.fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var statsPreview: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: initialDraft.kind.symbol)
                Text(initialDraft.kind == .milestone
                     ? (initialDraft.milestoneTitle ?? "Milestone")
                     : "DAY \(initialDraft.dayNumber)")
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(FMTheme.Colors.accent)

            if initialDraft.kind != .note {
                Text("\(initialDraft.completionPercent)% complete · \(initialDraft.streak) day streak")
                    .font(FMTheme.Typography.subheadline)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
            }

            if !initialDraft.habitNames.isEmpty {
                Text(initialDraft.habitNames.joined(separator: " · "))
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
    }

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
            Text("Photo (optional)")
                .font(FMTheme.Typography.headline)
                .foregroundStyle(FMTheme.Colors.textPrimary)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                if let image {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous)
                        .fill(FMTheme.Colors.surface)
                        .frame(height: 120)
                        .overlay(
                            Label("Add a photo", systemImage: "photo")
                                .font(FMTheme.Typography.subheadline)
                                .foregroundStyle(FMTheme.Colors.textTertiary)
                        )
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        image = UIImage(data: data)
                    }
                }
            }

            if image != nil {
                Button("Remove photo") { image = nil; pickerItem = nil }
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.danger)
            }
        }
    }

    private var privacyPicker: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
            Text("Visibility")
                .font(FMTheme.Typography.headline)
                .foregroundStyle(FMTheme.Colors.textPrimary)
            Picker("Visibility", selection: $privacy) {
                ForEach(PrivacyLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// Says plainly where the post goes. A social screen that stays quiet about this
    /// invites people to assume they're broadcasting when they aren't — or worse, to
    /// assume they aren't when they are.
    private var storageNotice: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lock.fill")
            Text(social.supportsOtherPeople
                 ? "Your visibility choice controls who can see this."
                 : "This stays on your device. There's no account and no server yet, so nothing is uploaded — your choice above is saved for when sharing with other people exists.")
        }
        .font(.system(size: 11))
        .foregroundStyle(FMTheme.Colors.textTertiary)
    }

    // MARK: - Actions

    private func post() {
        var draft = initialDraft
        draft.caption = caption
        draft.privacyLevel = privacy
        draft.image = image

        do {
            let created = try social.publish(draft, authorName: users.first?.name ?? "You")
            services.analytics.track(.shareCreated(template: draft.kind.rawValue))
            Haptics.notify(.success)
            onPosted?(created)
            dismiss()
        } catch {
            errorMessage = "Couldn't save that post. Your progress is still safe — try again."
        }
    }
}

#Preview {
    ComposePostView(initialDraft: SocialPostDraft(
        kind: .dayRecap, dayNumber: 17, completionPercent: 82, streak: 12,
        habitNames: ["10K Steps", "Read", "Drink Water"]
    ))
    .modelContainer(PreviewData.container)
}
