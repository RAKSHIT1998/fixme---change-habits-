import Testing
@testable import FixMe

struct StreakServiceTests {
    @Test func currentStreakCountsTrailingRun() {
        let (current, best) = StreakService.computeStreaks(dayCompletions: [true, false, true, true, true])
        #expect(current == 3)
        #expect(best == 3)
    }

    @Test func aSingleMissDoesNotZeroOutBestStreak() {
        let (_, best) = StreakService.computeStreaks(dayCompletions: [true, true, true, true, false, true])
        #expect(best == 4)
    }

    @Test func noCompletionsMeansNoStreak() {
        let (current, best) = StreakService.computeStreaks(dayCompletions: [false, false])
        #expect(current == 0)
        #expect(best == 0)
    }
}

struct XPServiceTests {
    @Test func verifiedCompletionEarnsBonusXP() {
        #expect(XPService.awardForCompletion(verified: true) == XPService.habitCompletionXP + XPService.verificationBonusXP)
    }

    @Test func unverifiedCompletionEarnsBaseXP() {
        #expect(XPService.awardForCompletion(verified: false) == XPService.habitCompletionXP)
    }
}

struct JourneyTests {
    @Test func dayNumberIsClampedWithinRange() {
        let journey = Journey(startDate: .now.startOfDay, lengthInDays: 90)
        #expect(journey.dayNumber(for: .now) == 1)
        #expect(journey.dayNumber(for: .now.addingTimeInterval(-86400)) == 1) // clamps below range
    }
}
