import SwiftUI

/// Rasterizes a `ShareCardView` into a `UIImage` using `ImageRenderer` — no UIKit
/// drawing code required, and it stays pixel-perfect with the on-screen preview.
@MainActor
enum ShareCardRenderer {
    static func render(_ card: ShareCardView, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        return renderer.uiImage
    }
}
