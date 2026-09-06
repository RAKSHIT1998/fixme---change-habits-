import SwiftUI

/// Primary call-to-action button — pill-shaped, accent-filled, with a satisfying press animation.
struct FMPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            Haptics.impact(.medium)
            action()
        } label: {
            HStack(spacing: FMTheme.Spacing.xs) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    if let icon { Image(systemName: icon) }
                    Text(title)
                }
            }
            .font(FMTheme.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isEnabled ? FMTheme.Colors.accent : FMTheme.Colors.accent.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.pill, style: .continuous))
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(FMTheme.Motion.snappy, value: isPressed)
    }
}

/// Secondary, low-emphasis button — outlined, for "not now" style actions.
struct FMSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            Text(title)
                .font(FMTheme.Typography.headline)
                .foregroundStyle(FMTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(FMTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.pill, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FMTheme.Radius.pill, style: .continuous)
                        .stroke(FMTheme.Colors.textTertiary.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        FMPrimaryButton(title: "Let's do this", icon: "arrow.right") {}
        FMPrimaryButton(title: "Verifying...", isLoading: true) {}
        FMSecondaryButton(title: "Not now") {}
    }
    .padding()
}
