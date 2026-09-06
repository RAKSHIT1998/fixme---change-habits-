import AVKit
import Photos
import SwiftUI

/// The share loop that actually travels.
///
/// A static card gets a like; a transformation video gets reposted. Everything in it is
/// already on the device — the daily photos and stats nothing else reads back out — so
/// this needs no server, no upload and no account, which is the only reason it can exist
/// in this app at all.
///
/// Deliberately never paywalled: gating the feature that brings new people in would be
/// taxing our own cheapest acquisition channel.
struct ProgressReelView: View {
    let journey: Journey
    let user: User?

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .idle
    @State private var progress: Double = 0
    @State private var reel: ProgressReel?
    @State private var player: AVPlayer?
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var savedToPhotos = false

    private enum Phase { case idle, building, ready }

    private var input: ReelInput { ReelInput(journey: journey, user: user) }

    private var shareMessage: String {
        let code = user?.referralCode ?? ""
        let day = journey.dayNumber()
        var lines = ["Day \(day) of \(journey.lengthInDays). Still going."]
        if !code.isEmpty {
            lines.append("Doing it in Fix Me — use code \(code) and we both get a free week.")
        }
        return lines.joined(separator: "\n\n")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FMTheme.Spacing.lg) {
                    preview
                    caption
                    actions
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Your reel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showShareSheet) {
                if let reel { ActivityShareSheet(items: [reel.url, shareMessage]) }
            }
            .alert("Saved to Photos", isPresented: $savedToPhotos) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Post it from Photos to TikTok, Reels or your story.")
            }
            .alert("Couldn't make the reel", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onDisappear {
                player?.pause()
                ReelComposer.clearPreviousReels(keeping: reel?.url)
            }
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous)
                .fill(Color.black)

            switch phase {
            case .idle:
                ReelSceneView(
                    kind: .hook(name: input.name, fromDay: 1, toDay: input.currentDay),
                    size: posterSize
                )
                .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))

            case .building:
                VStack(spacing: FMTheme.Spacing.md) {
                    ProgressView(value: progress)
                        .tint(FMTheme.Colors.accent)
                        .frame(width: posterSize.width * 0.6)
                    Text("Building your reel…")
                        .font(FMTheme.Typography.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

            case .ready:
                if let player {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
                }
            }
        }
        .frame(width: posterSize.width, height: posterSize.height)
        .shadow(color: FMTheme.Shadow.elevated, radius: 24, y: 12)
    }

    private var posterSize: CGSize {
        let width: CGFloat = 260
        return CGSize(width: width, height: width * 16 / 9)
    }

    private var caption: some View {
        VStack(spacing: FMTheme.Spacing.xs) {
            Text(phase == .ready ? "Ready to post." : "Your 90 days, as a video.")
                .font(FMTheme.Typography.title)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(FMTheme.Typography.subheadline)
                .foregroundStyle(FMTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var subtitle: String {
        switch phase {
        case .ready:
            guard let reel else { return "" }
            return "\(Int(reel.duration.rounded()))s · no sound, so you can add your own."
        default:
            let photos = min(input.photos.count, ReelStoryboard.maxPhotos)
            if photos == 0 {
                return "Built from your stats. Add a photo to your evening review and they'll show up here too."
            }
            return "Built from \(photos) of your daily photo\(photos == 1 ? "" : "s") and your real numbers. Made on your phone — nothing is uploaded."
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch phase {
        case .idle:
            FMPrimaryButton(title: "Make my reel", icon: "wand.and.stars") { build() }

        case .building:
            FMPrimaryButton(title: "Building…", icon: "hourglass", isLoading: true) {}
                .disabled(true)

        case .ready:
            VStack(spacing: FMTheme.Spacing.sm) {
                FMPrimaryButton(title: "Share", icon: "square.and.arrow.up") {
                    services.analytics.track(.reelExported(destination: "share_sheet"))
                    showShareSheet = true
                }
                FMSecondaryButton(title: "Save to Photos") { saveToPhotos() }
                Button("Rebuild") { build() }
                    .font(FMTheme.Typography.caption)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Actions

    private func build() {
        phase = .building
        progress = 0
        player?.pause()
        player = nil
        services.analytics.track(.reelStarted(dayNumber: input.currentDay))

        Task {
            do {
                let made = try await ReelComposer.make(from: input) { fraction in
                    progress = fraction
                }
                ReelComposer.clearPreviousReels(keeping: made.url)
                reel = made
                player = loopingPlayer(for: made.url)
                phase = .ready
                Haptics.notify(.success)
                services.analytics.track(.reelRendered(
                    seconds: Int(made.duration.rounded()),
                    scenes: made.sceneCount
                ))
            } catch {
                phase = .idle
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Reels are short; looping them mirrors how they'll actually be watched.
    private func loopingPlayer(for url: URL) -> AVPlayer {
        let player = AVPlayer(url: url)
        player.isMuted = true
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
        return player
    }

    private func saveToPhotos() {
        guard let reel else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    errorMessage = "Fix Me needs permission to add to Photos. You can grant it in Settings, or use Share instead."
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: reel.url)
            } completionHandler: { success, error in
                Task { @MainActor in
                    if success {
                        Haptics.notify(.success)
                        savedToPhotos = true
                        services.analytics.track(.reelExported(destination: "photos"))
                    } else {
                        errorMessage = error?.localizedDescription ?? "Couldn't save to Photos."
                    }
                }
            }
        }
    }
}

#Preview {
    ProgressReelView(journey: Journey(), user: User(name: "Alex"))
        .modelContainer(PreviewData.container)
}
