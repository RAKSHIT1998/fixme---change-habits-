import SwiftUI

/// Small label communicating *how* a habit was confirmed — never overstates AI certainty.
struct VerificationBadge: View {
    let type: VerificationType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.symbol)
            Text(type.badgeText)
        }
        .font(FMTheme.Typography.footnote)
        .foregroundStyle(FMTheme.Colors.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(FMTheme.Colors.surfaceElevated)
        .clipShape(Capsule())
    }
}

#Preview {
    HStack {
        VerificationBadge(type: .healthKit)
        VerificationBadge(type: .photoAI)
        VerificationBadge(type: .manual)
    }
    .padding()
}
