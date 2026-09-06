import WidgetKit
import SwiftUI

/// Home screen widget showing today's day number, completion, streak, and next habit.
/// Reads a lightweight snapshot the main app writes via `WidgetSnapshotStore` — see
/// `FixMe/Shared/WidgetSnapshot.swift`.
///
/// When nothing has been published, this shows an explicit empty state. It deliberately
/// does *not* fall back to sample data: doing so once made a Day 1 journey display as
/// Day 17 with a streak the user had never earned.
struct TodayProgressWidget: Widget {
    let kind = "TodayProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProgressProvider()) { entry in
            TodayProgressWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(hex: "16161A") }
        }
        .configurationDisplayName("Today's Progress")
        .description("See your day number, completion, and streak at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayProgressEntry: TimelineEntry {
    let date: Date
    /// Nil when the app hasn't published a journey yet.
    let snapshot: WidgetSnapshot?
}

struct TodayProgressProvider: TimelineProvider {
    /// Redacted skeleton shown while the widget loads — sample data is correct here.
    func placeholder(in context: Context) -> TodayProgressEntry {
        TodayProgressEntry(date: .now, snapshot: .galleryPreview)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayProgressEntry) -> Void) {
        // The widget gallery is the one place sample data belongs; everywhere else shows
        // the real state, including "nothing yet".
        let snapshot = context.isPreview ? .galleryPreview : WidgetSnapshotStore.load()
        completion(TodayProgressEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayProgressEntry>) -> Void) {
        let entry = TodayProgressEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        // Widgets can't observe SwiftData directly; refresh periodically and rely on
        // `WidgetCenter.reloadAllTimelines()` calls from the app for immediate updates.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct TodayProgressWidgetView: View {
    let entry: TodayProgressEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            progress(snapshot)
        } else {
            empty
        }
    }

    /// Honest about having no data, rather than inventing a journey.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FIX ME")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: 4)
            Text("No journey yet")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Open Fix Me to start your 90 days.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(4)
    }

    private func progress(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DAY \(snapshot.dayNumber)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            Text("\(snapshot.completionPercent)%")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 4) {
                Text("🔥")
                Text("\(snapshot.currentStreak) day streak")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 4)

            if let next = snapshot.nextHabitName {
                Text("Next: \(next)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(4)
    }
}

private extension Color {
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

#Preview(as: .systemSmall) {
    TodayProgressWidget()
} timeline: {
    TodayProgressEntry(date: .now, snapshot: .galleryPreview)
    TodayProgressEntry(date: .now, snapshot: nil)
}
