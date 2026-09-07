import Testing
import Foundation
import SwiftData
import CryptoKit
@testable import FixMe

/// Shared starts change the user's journey, so the tests lean hardest on what accepting an
/// invitation must never do to data that already exists.
@MainActor
struct PactServiceTests {
    let container: ModelContainer
    let calendar = Calendar.current

    init() throws {
        container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    private var context: ModelContext { container.mainContext }
    private var service: PactService { PactService(modelContext: context) }

    private func card(_ name: String) -> IdentityCard {
        let key = Curve25519.Signing.PrivateKey()
        return PeerIdentity(peerID: UUID().uuidString, displayName: name, publicKey: key.publicKey).card
    }

    private func payload(_ name: String = "Sam", startingIn days: Int = 3, length: Int = 90) -> PactInvitePayload {
        PactInvitePayload(
            card: card(name),
            startDate: calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: .now))!,
            lengthInDays: length,
            message: nil
        )
    }

    @Test func acceptingPairsTheDevicesAndStartsTheJourney() throws {
        let invite = payload()
        let pact = try service.accept(invite, ownPeerID: "me", existingJourney: nil)

        #expect(pact.partnerName == "Sam")
        #expect(pact.startsAligned)
        #expect(calendar.isDate(pact.startDate, inSameDayAs: invite.startDate))

        // Pairing happens in the same step — asking someone to accept and then separately
        // add a friend is where people drop out.
        let friend = FriendStore(modelContext: context).friend(peerID: invite.card.peerID)
        #expect(friend?.displayName == "Sam")

        let journeys = try context.fetch(FetchDescriptor<Journey>())
        #expect(journeys.count == 1)
        #expect(calendar.isDate(journeys[0].startDate, inSameDayAs: invite.startDate))
    }

    /// The one that matters. Moving an existing start date would renumber every day the
    /// user has already completed and invalidate their history.
    @Test func acceptingNeverRewritesAJourneyAlreadyInProgress() throws {
        let existingStart = calendar.date(byAdding: .day, value: -40, to: calendar.startOfDay(for: .now))!
        let journey = Journey(startDate: existingStart)
        context.insert(journey)

        let invite = payload()
        let pact = try service.accept(invite, ownPeerID: "me", existingJourney: journey)

        #expect(calendar.isDate(journey.startDate, inSameDayAs: existingStart), "existing run must be untouched")
        #expect(pact.startsAligned == false, "and the pact must admit the numbers won't line up")

        let journeys = try context.fetch(FetchDescriptor<Journey>())
        #expect(journeys.count == 1, "no second journey either")
    }

    /// An invitation that sat in a chat for a week shouldn't backdate days nobody did.
    @Test func aStartDateInThePastBeginsToday() throws {
        let stale = PactInvitePayload(
            card: card("Sam"),
            startDate: calendar.date(byAdding: .day, value: -5, to: calendar.startOfDay(for: .now))!,
            lengthInDays: 90,
            message: nil
        )
        let pact = try service.accept(stale, ownPeerID: "me", existingJourney: nil)

        let journey = try #require(try context.fetch(FetchDescriptor<Journey>()).first)
        #expect(calendar.isDate(journey.startDate, inSameDayAs: calendar.startOfDay(for: .now)))
        #expect(pact.startsAligned == false)
    }

    @Test func youCannotPactWithYourself() throws {
        let invite = payload()
        #expect(throws: PeerError.self) {
            try service.accept(invite, ownPeerID: invite.card.peerID, existingJourney: nil)
        }
    }

    @Test func dayNumbersLineUpOnBothSides() {
        let start = calendar.date(byAdding: .day, value: -11, to: calendar.startOfDay(for: .now))!
        let pact = Pact(partnerPeerID: "x", partnerName: "Sam", startDate: start)

        #expect(pact.hasStarted)
        #expect(pact.dayNumber() == 12)
        #expect(pact.daysUntilStart() == 0)
    }

    /// Before the start date there is no day number to show — a "Day 0" or "Day 1" would
    /// both be wrong, and the row says "starts in N days" instead.
    @Test func thereIsNoDayNumberBeforeTheStart() {
        let start = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: .now))!
        let pact = Pact(partnerPeerID: "x", partnerName: "Sam", startDate: start)

        #expect(pact.hasStarted == false)
        #expect(pact.dayNumber() == nil)
        #expect(pact.daysUntilStart() == 3)
    }

    @Test func aFinishedPactIsNoLongerActive() throws {
        let old = calendar.date(byAdding: .day, value: -200, to: calendar.startOfDay(for: .now))!
        context.insert(Pact(partnerPeerID: "x", partnerName: "Sam", startDate: old, lengthInDays: 90))
        try context.save()

        #expect(service.activePact() == nil)
    }
}

/// The link is the whole loop: it has to survive a round trip through a messaging app.
struct PactLinkTests {

    private func payload() -> PactInvitePayload {
        let key = Curve25519.Signing.PrivateKey()
        let identity = PeerIdentity(peerID: "sam-1", displayName: "Sam", publicKey: key.publicKey)
        return PactInvitePayload(
            card: identity.card,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            lengthInDays: 90,
            message: "let's go"
        )
    }

    @Test func aPactLinkRoundTrips() throws {
        let sent = payload()
        let url = try PeerLink.pactURL(for: sent)

        guard case let .pact(received) = try PeerLink.parse(url) else {
            Issue.record("expected a pact invitation")
            return
        }
        #expect(received.card.peerID == sent.card.peerID)
        #expect(received.card.displayName == "Sam")
        #expect(received.startDate == sent.startDate)
        #expect(received.lengthInDays == 90)
        #expect(received.message == "let's go")
    }

    /// Sent as https so it's tappable in every messenger and useful to someone without the
    /// app — the same fix the other invite links needed.
    @Test func itSurvivesTheHTTPSWrapper() throws {
        let sent = payload()
        let web = InviteLink.web(for: try PeerLink.pactURL(for: sent))
        #expect(web.scheme == "https")

        guard case let .pact(received) = try PeerLink.parse(web) else {
            Issue.record("expected a pact invitation through the web wrapper")
            return
        }
        #expect(received.card.peerID == sent.card.peerID)
        #expect(received.startDate == sent.startDate)
    }
}
