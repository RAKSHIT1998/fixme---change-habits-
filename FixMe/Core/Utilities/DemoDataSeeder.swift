import Foundation
import SwiftData
import CryptoKit

/// Populates a realistic Day-17 journey on launch when the app is started with
/// `-FixMeSeedDemo`. Useful for screenshots, demos and checking a screen without tapping
/// through onboarding first.
///
/// Debug builds only — it wipes and rewrites the store, which must never happen to a real
/// user's data.
enum DemoDataSeeder {

    static var isRequested: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-FixMeSeedDemo")
        #else
        false
        #endif
    }

    @MainActor
    static func seed(into container: ModelContainer) {
        #if DEBUG
        let context = container.mainContext

        // Start from a clean slate so repeated launches are deterministic.
        for user in (try? context.fetch(FetchDescriptor<User>())) ?? [] { context.delete(user) }
        for journey in (try? context.fetch(FetchDescriptor<Journey>())) ?? [] { context.delete(journey) }
        for alarm in (try? context.fetch(FetchDescriptor<HabitAlarm>())) ?? [] { context.delete(alarm) }
        for post in (try? context.fetch(FetchDescriptor<SocialPost>())) ?? [] { context.delete(post) }
        for friend in (try? context.fetch(FetchDescriptor<Friend>())) ?? [] { context.delete(friend) }

        let user = User(name: "Alex", totalXP: 860)
        user.settings = UserSettings(healthKitAuthorized: true, notificationsAuthorized: true)
        context.insert(user)

        let journey = Journey(
            startDate: Calendar.current.date(byAdding: .day, value: -16, to: .now.startOfDay) ?? .now
        )
        journey.owner = user
        context.insert(journey)

        // Build habits with 16 days of mostly-kept history.
        let blueprints = Array(HabitCatalog.all.prefix(4))
        for (index, blueprint) in blueprints.enumerated() {
            let habit = blueprint.makeHabit(sortOrder: index)
            habit.journey = journey
            context.insert(habit)

            for dayOffset in stride(from: -16, through: -1, by: 1) {
                let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: .now.startOfDay) ?? .now
                let completion = HabitCompletion(date: date)
                completion.habit = habit
                let missed = dayOffset == -5
                completion.state = missed ? .missed : .completed
                completion.progressValue = missed ? 0 : habit.goalTargetValue
                completion.xpAwarded = missed ? 0 : 20
                habit.completions.append(completion)
                context.insert(completion)
            }

            let today = HabitCompletion(date: .now)
            today.habit = habit
            switch index {
            case 0: today.state = .verified; today.progressValue = habit.goalTargetValue
            case 1: today.state = .inProgress; today.progressValue = 7482
            case 2: today.state = .inProgress; today.progressValue = 2100
            default: today.state = .notStarted
            }
            habit.completions.append(today)
            context.insert(today)
        }

        // A quit habit mid-run, with an earlier attempt behind it so the history-preserving
        // stats have something to show.
        let quit = Habit(
            name: "No smoking",
            iconSystemName: "nosign",
            category: .health,
            verificationType: .manual,
            goalDescription: "Stay smoke-free",
            sortOrder: blueprints.count,
            kind: .quit,
            quitProgramID: QuitProgram.smoking.id,
            quitStartDate: Calendar.current.date(byAdding: .day, value: -12, to: .now),
            unitsPerDay: 10,
            costPerUnit: 0.5
        )
        quit.journey = journey
        context.insert(quit)

        let earlierAttempt = RelapseEvent(
            date: Calendar.current.date(byAdding: .day, value: -12, to: .now) ?? .now,
            runDuration: 4 * 86_400,
            trigger: "Night out"
        )
        earlierAttempt.habit = quit
        quit.relapses.append(earlierAttempt)
        context.insert(earlierAttempt)

        for daysAgo in [1, 2, 4, 7] {
            let craving = CravingEvent(
                date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
                intensity: Int.random(in: 2...5),
                didResist: true,
                durationSeconds: 300
            )
            craving.habit = quit
            quit.cravings.append(craving)
            context.insert(craving)
        }

        let alarm = HabitAlarm(
            label: "Rise and shine",
            time: Date.fromComponents(hour: 6, minute: 0),
            weekdays: [2, 3, 4, 5, 6]
        )
        alarm.habit = quit.journey?.habits.first
        context.insert(alarm)

        // A few posts so the wall shows real content rather than only its empty state.
        let posts = [
            SocialPost(
                authorName: "Alex",
                caption: "Two weeks in. The 6am thing stopped feeling impossible somewhere around day 9.",
                dayNumber: 14, completionPercent: 100,
                createdAt: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now,
                heartCount: 4, fireCount: 2,
                kind: .milestone,
                habitNames: ["Wake up early", "10K Steps", "Drink Water", "Read"],
                streak: 14, milestoneTitle: "Two Weeks"
            ),
            SocialPost(
                authorName: "Alex",
                caption: "Missed yesterday. Back on it today — that's the whole trick apparently.",
                dayNumber: 16, completionPercent: 75,
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
                clapCount: 3,
                kind: .dayRecap,
                habitNames: ["10K Steps", "Drink Water", "Read"],
                streak: 1
            ),
        ]
        for post in posts { context.insert(post) }

        // A paired friend with a genuinely signed update, so the peer-to-peer feed shows
        // real verified data rather than a mock-up of it.
        let friendKey = Curve25519.Signing.PrivateKey()
        let friendIdentity = PeerIdentity(
            peerID: UUID().uuidString,
            displayName: "Sam",
            publicKey: friendKey.publicKey
        )
        let friend = Friend(
            peerID: friendIdentity.peerID,
            displayName: friendIdentity.displayName,
            publicKeyData: friendKey.publicKey.rawRepresentation,
            pairedNearby: true
        )
        context.insert(friend)

        if let envelope = try? SignedEnvelope.make(
            ProgressUpdatePayload(
                displayName: "Sam", dayNumber: 17, totalDays: 90,
                completionPercent: 100, streak: 17,
                habitNames: ["Wake up early", "Run", "Read"],
                message: "Perfect day. Your turn.",
                cleanDays: 31,
                createdAt: Calendar.current.date(byAdding: .hour, value: -5, to: .now) ?? .now
            ),
            kind: .progressUpdate,
            identity: friendIdentity,
            sign: { try friendKey.signature(for: $0) }
        ) {
            // Goes through the same verifying path a real update would.
            _ = try? FriendStore(modelContext: context).receive(envelope)
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: "fixme.hasCompletedOnboarding")
        #endif
    }
}
