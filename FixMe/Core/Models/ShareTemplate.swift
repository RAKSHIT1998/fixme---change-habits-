import Foundation
import CoreGraphics

/// Not persisted — a static catalog of share-card visual styles.
enum ShareTemplate: String, CaseIterable, Identifiable {
    case minimal, dark, light, fitness, morning, night, progress, ninetyDay, motivational, photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal: return "Minimal"
        case .dark: return "Dark"
        case .light: return "Light"
        case .fitness: return "Fitness"
        case .morning: return "Morning"
        case .night: return "Night"
        case .progress: return "Progress"
        case .ninetyDay: return "90-Day"
        case .motivational: return "Motivational"
        case .photo: return "Photo"
        }
    }
}

enum ShareExportFormat: String, CaseIterable, Identifiable {
    case instagramStory, instagramPost, square, portrait
    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .instagramStory: return CGSize(width: 1080, height: 1920)
        case .instagramPost: return CGSize(width: 1080, height: 1350)
        case .square: return CGSize(width: 1080, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1440)
        }
    }

    var title: String {
        switch self {
        case .instagramStory: return "Story"
        case .instagramPost: return "Post"
        case .square: return "Square"
        case .portrait: return "Portrait"
        }
    }
}
