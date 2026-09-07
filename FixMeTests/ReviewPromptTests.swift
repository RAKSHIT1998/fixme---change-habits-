import Testing
import Foundation
@testable import FixMe

/// iOS honours three rating prompts a year and silently discards the rest, so a prompt
/// spent on a bad day is gone for good. These pin the rules that decide which days count.
struct ReviewPromptTests {

    private func freshPrompt() -> ReviewPrompt {
        ReviewPrompt(defaults: UserDefaults(suiteName: "fixme.tests.\(UUID().uuidString)")!)
    }

    @Test func asksAfterAStrongDay() {
        #expect(freshPrompt().shouldAsk(dayNumber: 20, dailyScore: 90, appVersion: "1.0"))
    }

    /// The single most important rule here. Asking someone to rate the app on the day
    /// they had a bad one is how an app collects one-star reviews.
    @Test func staysQuietAfterAWeakDay() {
        #expect(freshPrompt().shouldAsk(dayNumber: 20, dailyScore: 40, appVersion: "1.0") == false)
    }

    /// Reaching day 30 is the achievement regardless of that day's tick count.
    @Test func milestoneDaysCountEvenWithAMiddlingScore() {
        #expect(freshPrompt().shouldAsk(dayNumber: 30, dailyScore: 55, appVersion: "1.0"))
        #expect(freshPrompt().shouldAsk(dayNumber: 31, dailyScore: 55, appVersion: "1.0") == false)
    }

    /// Nobody can judge a 90-day app on day three, and the prompt would be wasted.
    @Test func neverAsksInTheFirstWeek() {
        let prompt = freshPrompt()
        #expect(prompt.shouldAsk(dayNumber: 3, dailyScore: 100, appVersion: "1.0") == false)
        #expect(prompt.shouldAsk(dayNumber: ReviewPrompt.earliestDay, dailyScore: 100, appVersion: "1.0"))
    }

    /// Someone who saw the prompt already answered, whichever way they answered.
    @Test func onlyAsksOncePerVersion() {
        let prompt = freshPrompt()
        prompt.recordAsk(appVersion: "1.0")

        #expect(prompt.shouldAsk(dayNumber: 40, dailyScore: 100, appVersion: "1.0") == false)
    }

    @Test func waitsOutTheCooldownEvenOnANewVersion() {
        let prompt = freshPrompt()
        let asked = Date(timeIntervalSince1970: 1_700_000_000)
        prompt.recordAsk(appVersion: "1.0", now: asked)

        let tooSoon = asked.addingTimeInterval(30 * 86_400)
        #expect(prompt.shouldAsk(dayNumber: 40, dailyScore: 100, appVersion: "1.1", now: tooSoon) == false)

        let later = asked.addingTimeInterval(Double(ReviewPrompt.daysBetweenAsks + 1) * 86_400)
        #expect(prompt.shouldAsk(dayNumber: 40, dailyScore: 100, appVersion: "1.1", now: later))
    }

    @Test func recordingAnAskIsRemembered() {
        let prompt = freshPrompt()
        #expect(prompt.lastAskedAt == nil)

        prompt.recordAsk(appVersion: "2.0")
        #expect(prompt.lastAskedVersion == "2.0")
        #expect(prompt.lastAskedAt != nil)

        prompt.reset()
        #expect(prompt.lastAskedVersion == nil)
        #expect(prompt.lastAskedAt == nil)
    }
}
