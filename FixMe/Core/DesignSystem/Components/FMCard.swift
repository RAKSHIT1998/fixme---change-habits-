import SwiftUI

/// Base rounded-card container used throughout the app for a consistent surface language.
struct FMCard<Content: View>: View {
    var padding: CGFloat = FMTheme.Spacing.md
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(FMTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
            .shadow(color: FMTheme.Shadow.card, radius: 12, x: 0, y: 4)
    }
}
