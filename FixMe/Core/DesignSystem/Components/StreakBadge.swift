import SwiftUI

/// Small flame + day-count chip used across Today, Habit Detail, and Profile.
struct StreakBadge: View {
    let days: Int
    var style: Style = .filled

    enum Style { case filled, subtle }

    var body: some View {
        HStack(spacing: 4) {
            Text("🔥")
            Text("\(days) day\(days == 1 ? "" : "s")")
                .font(FMTheme.Typography.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(background)
        .clipShape(Capsule())
        .foregroundStyle(style == .filled ? .white : FMTheme.Colors.textPrimary)
    }

    private var background: some ShapeStyle {
        switch style {
        case .filled: return AnyShapeStyle(FMTheme.Colors.accent)
        case .subtle: return AnyShapeStyle(FMTheme.Colors.surfaceElevated)
        }
    }
}

/// XP floating "+N XP" toast used right after a habit completes.
struct XPFloatingBadge: View {
    let amount: Int
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Text("+\(amount) XP")
            .font(FMTheme.Typography.headline)
            .foregroundStyle(FMTheme.Colors.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) {
                    offset = -50
                    opacity = 0
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        StreakBadge(days: 12)
        StreakBadge(days: 1, style: .subtle)
        XPFloatingBadge(amount: 20)
    }
    .padding()
}
