import SwiftUI

/// Centralized design tokens. Every screen should pull colors, type, spacing and radii
/// from here rather than hard-coding values, so the whole app reads as one system.
enum FMTheme {

    enum Colors {
        // Brand accent — warm amber-orange. One strong accent, mostly neutral elsewhere.
        static let accent = Color(hex: "FF6B35")
        static let accentSoft = Color(hex: "FFB088")

        // Neutral surfaces — intentionally distinct light/dark, not a naive invert.
        static let background = Color("FMBackground", bundle: nil)
        static let surface = Color("FMSurface", bundle: nil)
        static let surfaceElevated = Color("FMSurfaceElevated", bundle: nil)

        static let textPrimary = Color("FMTextPrimary", bundle: nil)
        static let textSecondary = Color("FMTextSecondary", bundle: nil)
        static let textTertiary = Color("FMTextTertiary", bundle: nil)

        static let success = Color(hex: "34C759")
        static let warning = Color(hex: "FFB020")
        static let danger = Color(hex: "FF5A5F")
        static let info = Color(hex: "4DA3FF")

        // Category accent colors (habit cards, category chips).
        static func forCategory(_ category: HabitCategory) -> Color {
            switch category {
            case .energy: return Color(hex: "FF6B35")
            case .fitness: return Color(hex: "34C759")
            case .mind: return Color(hex: "9B6BFF")
            case .learning: return Color(hex: "4DA3FF")
            case .sleep: return Color(hex: "6E7EFF")
            case .nutrition: return Color(hex: "5FCB8B")
            case .calm: return Color(hex: "45C1C0")
            case .health: return Color(hex: "3AB0FF")
            case .digital: return Color(hex: "FF9F45")
            case .custom: return Color(hex: "FF6B35")
            }
        }
    }

    enum Typography {
        static func display(_ size: CGFloat = 40) -> Font { .system(size: size, weight: .bold, design: .rounded) }
        static let largeTitle = Font.system(size: 32, weight: .bold, design: .rounded)
        static let title = Font.system(size: 24, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .medium)
        static let caption = Font.system(size: 13, weight: .medium)
        static let footnote = Font.system(size: 12, weight: .regular)
        static let numeric = Font.system(size: 17, weight: .bold, design: .rounded).monospacedDigit()
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 18
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let pill: CGFloat = 999
    }

    enum Shadow {
        static let card = Color.black.opacity(0.08)
        static let elevated = Color.black.opacity(0.16)
    }

    enum Motion {
        static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.75)
        static let gentle = Animation.easeInOut(duration: 0.3)
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
