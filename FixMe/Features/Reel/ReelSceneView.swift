import SwiftUI

/// One reel frame, drawn at video resolution.
///
/// Designed for a phone screen at arm's length in a fast-scrolling feed: one idea per
/// frame, type large enough to read without pausing, and the wordmark on every single
/// frame — reels get re-cropped and re-uploaded, and a mark only on the end card doesn't
/// survive that.
struct ReelSceneView: View {
    let kind: ReelScene.Kind
    var size: CGSize = ReelVideoWriter.renderSize
    /// Photos are loaded once by the composer and handed in, so rendering stays cheap.
    var photo: UIImage?

    /// Everything below is specified against a 1080-wide frame and scaled from there.
    private var unit: CGFloat { size.width / 1080 }

    /// TikTok and Reels paint their own caption, username and audio row over roughly the
    /// bottom fifth of the video, and a profile row over the top. Anything that has to be
    /// read — the invite code above all — stays inside these insets or it ships covered up.
    private var safeTop: CGFloat { 240 * unit }
    private var safeBottom: CGFloat { 420 * unit }

    var body: some View {
        ZStack {
            background
            content
            watermark
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
        .clipped()
    }

    // MARK: - Frames

    @ViewBuilder
    private var content: some View {
        switch kind {
        case let .hook(name, fromDay, toDay):
            hookFrame(name: name, fromDay: fromDay, toDay: toDay)
        case let .photo(_, dayNumber):
            photoFrame(dayNumber: dayNumber)
        case let .stat(value, label, footnote):
            statFrame(value: value, label: label, footnote: footnote)
        case let .endCard(headline, code):
            endFrame(headline: headline, code: code)
        }
    }

    private func hookFrame(name: String, fromDay: Int, toDay: Int) -> some View {
        VStack(spacing: 24 * unit) {
            if !name.isEmpty {
                Text(name.uppercased())
                    .font(.system(size: 40 * unit, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(6 * unit)
            }
            HStack(alignment: .center, spacing: 34 * unit) {
                dayToken("\(fromDay)")
                Image(systemName: "arrow.right")
                    .font(.system(size: 110 * unit, weight: .black))
                    .foregroundStyle(FMTheme.Colors.accent)
                dayToken("\(toDay)")
            }
            .frame(maxWidth: .infinity)
            Text("DAYS")
                .font(.system(size: 44 * unit, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(14 * unit)
        }
        .padding(.horizontal, 80 * unit)
    }

    private func dayToken(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 190 * unit, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.4)
            .lineLimit(1)
    }

    private func photoFrame(dayNumber: Int) -> some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            }
            LinearGradient(
                colors: [.black.opacity(0.65), .clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack {
                Spacer()
                HStack {
                    Text("DAY \(dayNumber)")
                        .font(.system(size: 96 * unit, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 20 * unit, y: 6 * unit)
                    Spacer()
                }
                .padding(.horizontal, 80 * unit)
                .padding(.bottom, safeBottom)
            }
        }
    }

    private func statFrame(value: String, label: String, footnote: String?) -> some View {
        VStack(spacing: 18 * unit) {
            Text(value)
                .font(.system(size: 260 * unit, weight: .black, design: .rounded))
                .foregroundStyle(FMTheme.Colors.accent)
                .minimumScaleFactor(0.35)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 60 * unit, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .tracking(4 * unit)
                .multilineTextAlignment(.center)
            if let footnote {
                Text(footnote)
                    .font(.system(size: 34 * unit, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3 * unit)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 90 * unit)
    }

    private func endFrame(headline: String, code: String) -> some View {
        VStack(spacing: 30 * unit) {
            Spacer(minLength: safeTop)
            Text(headline)
                .font(.system(size: 110 * unit, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
            Text("Still going.")
                .font(.system(size: 46 * unit, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            VStack(spacing: 14 * unit) {
                Text("FIX ME")
                    .font(.system(size: 78 * unit, weight: .black, design: .rounded))
                    .foregroundStyle(FMTheme.Colors.accent)
                    .tracking(10 * unit)
                Text("90 days. Better habits. Better you.")
                    .font(.system(size: 36 * unit, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                if !code.isEmpty {
                    Text("CODE \(code)")
                        .font(.system(size: 34 * unit, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 36 * unit)
                        .padding(.vertical, 18 * unit)
                        .background(
                            Capsule().stroke(.white.opacity(0.35), lineWidth: 3 * unit)
                        )
                        .padding(.top, 10 * unit)
                }
            }
            .padding(.bottom, safeBottom)
        }
        .padding(.horizontal, 90 * unit)
    }

    // MARK: - Chrome

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .photo:
            Color.black
        case .endCard:
            LinearGradient(
                colors: [Color(hex: "1A0E08"), Color(hex: "0B0B0D")],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            LinearGradient(
                colors: [Color(hex: "141414"), Color(hex: "0B0B0D")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Never sold as a premium removal — the watermark is the acquisition channel.
    @ViewBuilder
    private var watermark: some View {
        if case .endCard = kind {
            EmptyView()
        } else {
            VStack {
                Text("FIX ME")
                    .font(.system(size: 34 * unit, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(8 * unit)
                    .padding(.top, safeTop * 0.6)
                Spacer()
            }
        }
    }
}

#Preview("Hook") {
    ReelSceneView(kind: .hook(name: "Alex", fromDay: 1, toDay: 47), size: CGSize(width: 270, height: 480))
}

#Preview("Stat") {
    ReelSceneView(
        kind: .stat(value: "47", label: "DAYS CLEAN", footnote: "SMOKING"),
        size: CGSize(width: 270, height: 480)
    )
}

#Preview("End card") {
    ReelSceneView(kind: .endCard(headline: "47 days clean.", code: "A1B2C3"), size: CGSize(width: 270, height: 480))
}
