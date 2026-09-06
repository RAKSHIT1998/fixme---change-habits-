import SwiftUI

/// The actual visual share card — rendered live in the picker and rasterized for export.
/// Distinct styling per `ShareTemplate`, always including the Fix Me watermark.
struct ShareCardView: View {
    let template: ShareTemplate
    let dayNumber: Int
    let totalDays: Int
    let completionPercent: Int
    let streak: Int
    let habitNames: [String]
    var photo: UIImage? = nil
    var quote: String = "Still showing up."
    var size: CGSize = CGSize(width: 360, height: 640)

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 14) {
                Text("DAY \(dayNumber) / \(totalDays)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(foreground.opacity(0.7))

                if let photo, template == .photo {
                    Image(uiImage: photo)
                        .resizable().scaledToFill()
                        .frame(height: size.height * 0.35)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                HStack(spacing: 6) {
                    Text("🔥").font(.system(size: 26))
                    Text("\(completionPercent)% COMPLETE")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(foreground)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(habitNames, id: \.self) { name in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                            Text(name).font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(foreground.opacity(0.85))
                    }
                }

                Spacer()

                Text(quote)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(foreground)

                HStack {
                    Text("FIX ME").font(.system(size: 13, weight: .bold, design: .rounded))
                    Spacer()
                    Text("@fixme").font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(foreground.opacity(0.5))
            }
            .padding(24)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var foreground: Color {
        switch template {
        case .light, .minimal, .morning: return .black
        default: return .white
        }
    }

    @ViewBuilder
    private var background: some View {
        switch template {
        case .minimal: Color.white
        case .dark: Color.black
        case .light: Color(white: 0.96)
        case .fitness: LinearGradient(colors: [Color(hex: "0F172A"), Color(hex: "134E4A")], startPoint: .top, endPoint: .bottom)
        case .morning: LinearGradient(colors: [Color(hex: "FFE8D6"), Color(hex: "FFC29E")], startPoint: .top, endPoint: .bottom)
        case .night: LinearGradient(colors: [Color(hex: "0B0B2A"), Color(hex: "1B1B4A")], startPoint: .top, endPoint: .bottom)
        case .progress: LinearGradient(colors: [Color(hex: "1A1A1A"), Color(hex: "3A2A1A")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ninetyDay: LinearGradient(colors: [FMTheme.Colors.accent, Color(hex: "FFB088")], startPoint: .top, endPoint: .bottom)
        case .motivational: LinearGradient(colors: [Color(hex: "1E1E1E"), FMTheme.Colors.accent.opacity(0.4)], startPoint: .bottomLeading, endPoint: .topTrailing)
        case .photo: Color.black
        }
    }
}

#Preview {
    ShareCardView(
        template: .ninetyDay,
        dayNumber: 17,
        totalDays: 90,
        completionPercent: 82,
        streak: 12,
        habitNames: ["10K steps", "Workout", "Read 20 pages", "3L water"]
    )
}
