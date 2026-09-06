import SwiftUI

/// Animated "scanning" line shown over the captured photo while AI verification runs.
struct ScanningOverlay: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous)
                .stroke(FMTheme.Colors.accent.opacity(0.6), lineWidth: 2)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(
                            LinearGradient(colors: [.clear, FMTheme.Colors.accent, .clear], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(height: 3)
                        .offset(y: animate ? geo.size.height : 0)
                        .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: animate)
                }
        }
        .onAppear { animate = true }
    }
}

#Preview {
    ScanningOverlay()
        .frame(width: 260, height: 260)
        .background(Color.black)
}
