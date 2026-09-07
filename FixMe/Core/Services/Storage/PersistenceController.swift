import Foundation
import SwiftData

enum PersistenceController {
    /// The full SwiftData schema for the app.
    static var schema: Schema {
        Schema([
            User.self,
            UserSettings.self,
            Habit.self,
            HabitCompletion.self,
            VerificationResult.self,
            Journey.self,
            DayProgress.self,
            DailyPhoto.self,
            Streak.self,
            Badge.self,
            HabitTemplate.self,
            SocialPost.self,
            NotificationPreference.self,
            RelapseEvent.self,
            CravingEvent.self,
            HabitAlarm.self,
            Friend.self,
            FriendUpdate.self,
            StakeChallenge.self,
            Pact.self,
        ])
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fall back to an in-memory store rather than crashing on a migration failure.
            // Deliberately not an assertionFailure: a schema change during development
            // would otherwise take down every debug launch instead of degrading.
            print("[storage] Persistent store unavailable, using in-memory: \(error)")
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }
}
