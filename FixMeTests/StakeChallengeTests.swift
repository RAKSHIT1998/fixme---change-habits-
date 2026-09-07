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

/// What gets scheduled, and — more importantly — what doesn't.
@MainActor
struct StakeNotificationPlanTests {
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
    private func day(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n - 1, to: start())! }
    /// A time on day `n`, so "before/after the 8am and 8:30pm slots" is expressible.
    private func day(_ n: Int, atHour hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day(n))!
    }

    private func challenge(length: Int = 90) -> StakeChallenge {
        let c = StakeChallenge(startDate: start(), lengthInDays: length, stakeAmount: 50)
        container.mainContext.insert(c)
        return c
    }

    private func habit() -> Habit {
        let h = Habit(name: "Read", iconSystemName: "book", category: .learning,
                      verificationType: .manual, goalDescription: "", createdAt: start())
        container.mainContext.insert(h)
        return h
    }

    private func complete(_ habit: Habit, onDay n: Int) {
        let completion = HabitCompletion(date: day(n), state: .completed)
        completion.habit = habit
        habit.completions.append(completion)
    }

    /// The behaviour the whole design rests on: finishing the day stands the threat down.
    /// A warning that fires after the day is safe teaches people these notifications lie.
    @Test func todaysWarningDisappearsOnceTheDayIsDone() {
        let c = challenge()
        let h = habit()
        let noon = day(1, atHour: 12)

        let whileOpen = StakeNotifications.plan(challenge: c, habits: [h], calendar: calendar, now: noon)
        #expect(whileOpen.contains { $0.kind == .warning && $0.day == 1 })

        complete(h, onDay: 1)

        let whenDone = StakeNotifications.plan(challenge: c, habits: [h], calendar: calendar, now: noon)
        #expect(whenDone.contains { $0.kind == .warning && $0.day == 1 } == false)
        // Tomorrow's reminders still stand — only today's threat is retired.
        #expect(whenDone.contains { $0.day == 2 })
    }

    @Test func todaysWarningNamesWhatIsOpenAndWhatItCosts() throws {
        let c = challenge()
        let h = habit()
        let plan = StakeNotifications.plan(challenge: c, habits: [h], calendar: calendar, now: day(1, atHour: 12))

        let warning = try #require(plan.first { $0.kind == .warning && $0.day == 1 })
        #expect(warning.body.contains("1 habit left"))
        // Compared against the challenge's own formatting rather than a literal: the stake
        // is shown in the user's currency, so "$50" only passes on a US-locale machine.
        #expect(warning.body.contains(c.formattedStake))
    }

    /// A "good morning, day 34" arriving in the afternoon reads as a bug.
    @Test func todaysMorningIsSkippedOnceTheMorningHasPassed() {
        let c = challenge()
        let h = habit()

        let earlyPlan = StakeNotifications.plan(challenge: c, habits: [h], calendar: calendar, now: day(1, atHour: 6))
        #expect(earlyPlan.contains { $0.kind == .morning && $0.day == 1 })

        let latePlan = StakeNotifications.plan(challenge: c, habits: [h], calendar: calendar, now: day(1, atHour: 12))
        #expect(latePlan.contains { $0.kind == .morning && $0.day == 1 } == false)
    }

    /// iOS allows 64 pending notifications for the whole app, alarms included. Ninety days
    /// of reminders would blow through that and silently drop the ones that matter.
    @Test func staysWellInsideTheSystemLimit() {
        let c = challenge()
        let h = habit()
        let plan = StakeNotifications.plan(challenge: c, habits: [h], calendar: calendar, now: day(1, atHour: 6))

        #expect(plan.count <= StakeNotifications.windowDays * 2)
        #expect(plan.count < 20, "has to leave room for alarms in the same 64-slot budget")
        #expect(Set(plan.map(\.id)).count == plan.count, "duplicate ids would overwrite each other")
    }

    @Test func nothingIsPlannedPastTheFinalDay() {
        let c = challenge(length: 2)
        let h = habit()
        let plan = StakeNotifications.plan(challenge: c, habits: [h], calendar: calendar, now: day(1, atHour: 6))

        #expect(plan.allSatisfy { $0.day <= 2 })
    }

    /// Nagging someone about a challenge they already lost is the worst message this app
    /// could send.
    @Test func aResolvedChallengeSchedulesNothing() {
        let c = challenge()
        let h = habit()
        c.outcome = .lost
        c.failedOnDay = 1

        #expect(StakeNotifications.plan(challenge: c, habits: [h], calendar: calendar, now: day(2, atHour: 6)).isEmpty)
    }
}

/// When to *ask* someone to stake money. Getting this wrong is worse than not asking:
/// this is the one prompt in the app that costs the user real money to say yes to.
struct StakeInvitationTests {

    @Test func offersOnceThereIsARunWorthProtecting() {
        #expect(StakeInvitation.shouldOffer(dayNumber: 12, habitCount: 3, longestStreak: 8, dismissedOnDay: 0))
    }

    /// Asking someone on day 2 to bet on 90 days is asking a stranger for money.
    @Test func neverAsksTooEarly() {
        #expect(StakeInvitation.shouldOffer(dayNumber: 3, habitCount: 3, longestStreak: 3, dismissedOnDay: 0) == false)
    }

    /// Offering a stake to someone already missing days is selling them a loss.
    @Test func neverAsksSomeoneWhoIsStruggling() {
        #expect(StakeInvitation.shouldOffer(dayNumber: 40, habitCount: 3, longestStreak: 1, dismissedOnDay: 0) == false)
    }

    @Test func neverAsksWithNoHabits() {
        #expect(StakeInvitation.shouldOffer(dayNumber: 40, habitCount: 0, longestStreak: 9, dismissedOnDay: 0) == false)
    }

    /// "Not for me" has to mean it for a good while, not until tomorrow morning.
    @Test func backsOffAfterBeingWavedAway() {
        #expect(StakeInvitation.shouldOffer(dayNumber: 21, habitCount: 3, longestStreak: 9, dismissedOnDay: 20) == false)
        #expect(StakeInvitation.shouldOffer(dayNumber: 35, habitCount: 3, longestStreak: 9, dismissedOnDay: 20))
    }
}
