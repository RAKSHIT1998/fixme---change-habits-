import SwiftUI

/// Large circular progress indicator used on Today and Journey screens.
struct ProgressRing: View {
    let progress: Double   // 0...1
    var lineWidth: CGFloat = 14
    var size: CGFloat = 160
    var ringColor: Color = FMTheme.Colors.accent
    var trackColor: Color = FMTheme.Colors.surfaceElevated

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.6), ringColor],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .onAppear { animate() }
        .onChange(of: progress) { _, _ in animate() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    private func animate() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
            animatedProgress = min(max(progress, 0), 1)
        }
    }
}

#Preview {
    ZStack {
        ProgressRing(progress: 0.67)
        VStack(spacing: 2) {
            Text("TODAY").font(FMTheme.Typography.caption).foregroundStyle(.secondary)
            Text("67%").font(FMTheme.Typography.display(36))
        }
    }
    .padding()
}
