import Foundation

/// Small, Codable summary of "right now" state, written by the main app and read by the
/// widget extension via an App Group container. Deliberately minimal — widgets don't need
/// (and shouldn't hold) direct SwiftData access to the full store.
struct WidgetSnapshot: Codable {
    var dayNumber: Int
    var totalDays: Int
    var completionPercent: Int
    var currentStreak: Int
    var nextHabitName: String?
    var updatedAt: Date

    /// Sample data for the widget **gallery only**, where Apple expects a representative
    /// preview. It must never be used as a fallback for missing data: a user with no
    /// journey would see an invented Day 17 with a 12-day streak they never earned.
    static let galleryPreview = WidgetSnapshot(
        dayNumber: 17, totalDays: 90, completionPercent: 67,
        currentStreak: 12, nextHabitName: "10K Steps", updatedAt: .now
    )
}

/// Reads/writes the snapshot through the shared App Group container.
///
/// The group identifier comes from each target's Info.plist (`FMAppGroupIdentifier`,
/// populated from `Signing.xcconfig`) rather than a literal, so renaming the bundle id
/// can't silently break sharing between the app and its widget.
///
/// When the App Group entitlement isn't present — which is the case on a free Personal
/// Team, where Apple doesn't allow it — `UserDefaults(suiteName:)` returns nil. Every
/// call here then becomes a no-op and the widget shows its placeholder, rather than the
/// app crashing or writing to a container nobody reads.
enum WidgetSnapshotStore {
    private static let key = "fixme.widget.snapshot"

    private static var appGroupID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "FMAppGroupIdentifier") as? String,
              !id.isEmpty,
              // An unexpanded build setting means the config wasn't applied.
              !id.hasPrefix("$(")
        else { return nil }
        return id
    }

    /// Nil when this build has no App Group entitlement.
    private static var defaults: UserDefaults? {
        guard let appGroupID else { return nil }
        return UserDefaults(suiteName: appGroupID)
    }

    /// Whether cross-process sharing is actually available in this build.
    static var isSharingAvailable: Bool { defaults != nil }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    /// Nil when the app hasn't published anything yet — the widget must show an empty
    /// state rather than substituting sample data.
    static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Called when there's no active journey, so the widget doesn't keep showing a
    /// finished or deleted one.
    static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
