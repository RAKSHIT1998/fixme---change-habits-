import SwiftUI
import UIKit

/// Wraps `UIActivityViewController` — the user decides where a share card goes.
/// Fix Me never auto-posts anywhere.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
