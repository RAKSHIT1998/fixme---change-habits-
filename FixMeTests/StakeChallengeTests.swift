import Testing
import Foundation
import SwiftData
@testable import FixMe

/// This is the only code in the app that can take something away from someone, so the
/// rules get tested harder than anything else here — including the ways it must *not*
/// fail someone.
@MainActor
struct StakeRulesTests {
    let container: ModelContainer
    let calendar = Calendar.current

    init() throws {
        container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func start() -> Date { calendar.startOfDay(for: day0) }
    private func day(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: n - 1, to: start())!
    }

    private func challenge(length: Int = 90) -> StakeChallenge {
        let challenge = StakeChallenge(startDate: start(), lengthInDays: length, stakeAmount: 50)
        container.mainContext.insert(challenge)
        return challenge
    }

    private func habit(_ name: String = "Read", createdOnDay: Int = 1, kind: HabitKind = .build) -> Habit {
        let habit = Habit(
            name: name,
            iconSystemName: "book",
            category: .learning,
            verificationType: .manual,
            goalDescription: "",
            createdAt: day(createdOnDay),
            kind: kind
        )
        container.mainContext.insert(habit)
        return habit
    }

    private func complete(_ habit: Habit, onDay n: Int) {
        let completion = HabitCompletion(date: day(n), state: .completed)
        completion.habit = habit
        habit.completions.append(completion)
    }

    // MARK: - Staying alive

    @Test func aFullyKeptRunIsSafe() {
        let c = challenge()
        let h = habit()
        for n in 1...5 { complete(h, onDay: n) }

        let status = StakeRules.status(for: c, habits: [h], calendar: calendar, now: day(5))
        #expect(status == .safe(day: 5, daysRemaining: 85))
    }

    /// The current day must never fail you — it isn't over yet. Getting this wrong would
    /// end someone's challenge at 00:01 every morning.
    @Test func todayIsNeverJudged() {
        let c = challenge()
        let h = habit()
        complete(h, onDay: 1)
        // Day 2 is today and nothing is done yet.
        let status = StakeRules.status(for: c, habits: [h], calendar: calendar, now: day(2))
        #expect(status == .atRisk(day: 2, daysRemaining: 88, openHabits: 1))
    }

    // MARK: - Losing

    @Test func oneMissedDayEndsIt() {
        let c = challenge()
        let h = habit()
        complete(h, onDay: 1)
        complete(h, onDay: 3)   // day 2 skipped

        let status = StakeRules.status(for: c, habits: [h], calendar: calendar, now: day(4))
        #expect(status == .lost(onDay: 2))
    }

    /// Every habit, every day — finishing one of two isn't finishing the day.
    @Test func partialDaysCountAsMissed() {
        let c = challenge()
        let reading = habit("Read")
        let water = habit("Water")
        complete(reading, onDay: 1)   // water not done

        let status = StakeRules.status(for: c, habits: [reading, water], calendar: calendar, now: day(2))
        #expect(status == .lost(onDay: 1))
    }

    /// A resolved outcome is a fact, not a live calculation — re-running the rules must
    /// never resurrect a lost challenge.
    @Test func aLostChallengeStaysLost() {
        let c = challenge()
        c.outcome = .lost
        c.failedOnDay = 12
        let h = habit()
        for n in 1...20 { complete(h, onDay: n) }

        #expect(StakeRules.status(for: c, habits: [h], calendar: calendar, now: day(20)) == .lost(onDay: 12))
    }

    // MARK: - Ways it must NOT fail someone

    /// Adding a habit on day 40 must not retroactively fail days 1–39.
    @Test func habitsAddedLaterDoNotFailEarlierDays() {
        let c = challenge()
        let original = habit(createdOnDay: 1)
        let added = habit(createdOnDay: 3)
        for n in 1...3 { complete(original, onDay: n) }
        complete(added, onDay: 3)

        // Day 4 is today with nothing done yet, so at-risk is right. What matters is that
        // days 1-2 weren't failed by a habit that didn't exist then.
        let status = StakeRules.status(for: c, habits: [original, added], calendar: calendar, now: day(4))
        #expect(status == .atRisk(day: 4, daysRemaining: 86, openHabits: 2))
    }

    /// A day with nothing scheduled is the app's gap, not the user's failure.
    @Test func aDayWithNoHabitsCannotBeFailed() {
        let c = challenge()
        let late = habit(createdOnDay: 5)
        complete(late, onDay: 5)

        let status = StakeRules.status(for: c, habits: [late], calendar: calendar, now: day(5))
        #expect(status == .safe(day: 5, daysRemaining: 85))
    }

    /// Quit habits invert everywhere else in the app, and must invert here too: clean
    /// unless a relapse was logged. Requiring a daily tick would fail every quit habit.
    @Test func quitHabitsCountAsKeptWithoutATick() {
        let c = challenge()
        let quit = habit(kind: .quit)

        let status = StakeRules.status(for: c, habits: [quit], calendar: calendar, now: day(4))
        #expect(status == .safe(day: 4, daysRemaining: 86))
    }

    @Test func aLoggedRelapseEndsIt() {
        let c = challenge()
        let quit = habit(kind: .quit)
        let relapse = RelapseEvent(date: day(2))
        relapse.habit = quit
        quit.relapses.append(relapse)

        let status = StakeRules.status(for: c, habits: [quit], calendar: calendar, now: day(4))
        #expect(status == .lost(onDay: 2))
    }

    // MARK: - Winning

    @Test func keepingEveryDayWins() {
        let c = challenge(length: 5)
        let h = habit()
        for n in 1...5 { complete(h, onDay: n) }

        #expect(StakeRules.status(for: c, habits: [h], calendar: calendar, now: day(6)) == .won)
    }

    /// The last day still has to be kept — a challenge isn't won by reaching day 90, it's
    /// won by finishing it.
    @Test func missingTheFinalDayStillLoses() {
        let c = challenge(length: 5)
        let h = habit()
        for n in 1...4 { complete(h, onDay: n) }

        #expect(StakeRules.status(for: c, habits: [h], calendar: calendar, now: day(6)) == .lost(onDay: 5))
    }
}

@MainActor
struct StakeServiceTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    @Test func startingRecordsTheTermsAndTheStake() {
        let service = StakeService(modelContext: container.mainContext)
        let journey = Journey()
        container.mainContext.insert(journey)

        let challenge = service.start(journey: journey, stakeAmount: 50, stakeHolder: "Sam", referee: nil)

        #expect(challenge.isActive)
        #expect(challenge.stakeAmount == 50)
        #expect(challenge.stakeHolder == "Sam")
        #expect(challenge.lengthInDays == journey.lengthInDays)
        #expect(service.activeStake()?.id == challenge.id)
    }

    /// Walking away has to cost what failing costs, or the stake means nothing.
    @Test func givingUpRecordsALoss() {
        let service = StakeService(modelContext: container.mainContext)
        let journey = Journey()
        container.mainContext.insert(journey)
        let challenge = service.start(journey: journey, stakeAmount: 50, stakeHolder: "Sam", referee: nil)

        service.giveUp(challenge, onDay: 12)

        #expect(challenge.outcome == .lost)
        #expect(challenge.failedOnDay == 12)
        #expect(service.activeStake() == nil)
    }
}

@MainActor
struct StakeNotificationCopyTests {

    /// Early on the money is the motivator; deep in, the sunk effort is worth more than
    /// the money and the copy should say so.
    @Test func remindersEscalateWithWhatIsActuallyAtStake() {
        let early = StakeNotifications.morningBody(day: 3, total: 90, stake: "$50")
        let deep = StakeNotifications.morningBody(day: 60, total: 90, stake: "$50")
        let last = StakeNotifications.morningBody(day: 90, total: 90, stake: "$50")

        #expect(early.contains("$50"))
        #expect(deep.contains("more than $50"))
        #expect(last.contains("Last day"))
    }
}
