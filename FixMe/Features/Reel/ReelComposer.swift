import SwiftUI
import UIKit

/// A finished reel, ready to preview and post.
struct ProgressReel {
    let url: URL
    let duration: Double
    let poster: UIImage
    let sceneCount: Int
}

/// Renders the storyboard to artwork, then hands it to `ReelVideoWriter`.
///
/// Rendering has to happen on the main actor (`ImageRenderer` requirement), so scenes are
/// rasterized once up front and the encoder — which is the slow half — runs off it.
@MainActor
enum ReelComposer {
    /// Rasterizing is fast relative to encoding; this split keeps the progress bar honest.
    private static let renderShare = 0.35

    /// `size` is only lowered by tests — see `ReelVideoWriter.write`.
    static func make(
        from input: ReelInput,
        size: CGSize = ReelVideoWriter.renderSize,
        onProgress: @escaping @MainActor (Double) -> Void = { _ in }
    ) async throws -> ProgressReel {
        let scenes = ReelStoryboard.scenes(for: input)
        guard !scenes.isEmpty else { throw ReelVideoError.nothingToRender }

        var stills: [ReelVideoWriter.Still] = []
        var poster: UIImage?

        for (index, scene) in scenes.enumerated() {
            let photo: UIImage? = {
                guard case let .photo(fileName, _) = scene.kind else { return nil }
                return ImageStore.load(fileName)
            }()

            // A photo scene whose file has been deleted from Settings would render as an
            // empty black frame, so drop it rather than show a hole in the story.
            if case .photo = scene.kind, photo == nil { continue }

            let view = ReelSceneView(kind: scene.kind, size: size, photo: photo)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            renderer.proposedSize = ProposedViewSize(size)

            guard let image = renderer.uiImage, let cgImage = image.cgImage else { continue }
            if poster == nil { poster = image }
            stills.append(ReelVideoWriter.Still(image: cgImage, duration: scene.duration))

            onProgress(Double(index + 1) / Double(scenes.count) * renderShare)
        }

        guard let poster, !stills.isEmpty else { throw ReelVideoError.nothingToRender }

        let url = try await ReelVideoWriter.write(stills: stills, size: size) { fraction in
            Task { @MainActor in
                onProgress(renderShare + fraction * (1 - renderShare))
            }
        }

        return ProgressReel(
            url: url,
            duration: stills.reduce(0) { $0 + $1.duration },
            poster: poster,
            sceneCount: stills.count
        )
    }

    /// Reels are written to the temp directory and are disposable; clear previous ones so
    /// repeated exports don't quietly accumulate tens of megabytes.
    static func clearPreviousReels(keeping url: URL? = nil) {
        let temp = FileManager.default.temporaryDirectory
        let contents = (try? FileManager.default.contentsOfDirectory(at: temp, includingPropertiesForKeys: nil)) ?? []
        for file in contents where file.lastPathComponent.hasPrefix("FixMeReel-") && file != url {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
