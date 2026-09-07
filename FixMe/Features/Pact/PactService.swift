import Foundation
import SwiftData

/// Creating and accepting shared starts.
@MainActor
struct PactService {
    let modelContext: ModelContext

    /// How far ahead a shared start can be set. Far enough to pick a Monday, near enough
    /// that the person who agreed still remembers agreeing.
    static let maxDaysAhead = 14

    func activePact(now: Date = .now, calendar: Calendar = .current) -> Pact? {
        let pacts = (try? modelContext.fetch(
            FetchDescriptor<Pact>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        )) ?? []
        // A pact stops being interesting once its run is over. One that hasn't started
        // yet is very much still active — that's the countdown the row exists to show.
        return pacts.first { !$0.isFinished(on: now, calendar: calendar) }
    }

    /// The payload to put in an invite link.
    func invitePayload(
        card: IdentityCard,
        startDate: Date,
        lengthInDays: Int,
        message: String?
    ) -> PactInvitePayload {
        PactInvitePayload(
            card: card,
            startDate: Calendar.current.startOfDay(for: startDate),
            lengthInDays: lengthInDays,
            message: message?.isEmpty == true ? nil : message
        )
    }

    /// Records the sender's own half. Called when the invite is actually sent — the pact is
    /// one-sided until the other person accepts, which is honest: they might not.
    @discardableResult
    func recordSentInvite(to card: IdentityCard, payload: PactInvitePayload, aligned: Bool) -> Pact {
        let pact = Pact(
            partnerPeerID: card.peerID,
            partnerName: card.displayName,
            startDate: payload.startDate,
            lengthInDays: payload.lengthInDays,
            startsAligned: aligned
        )
        modelContext.insert(pact)
        try? modelContext.save()
        return pact
    }

    /// Accepts an invitation: pairs the two devices, then lines up the start date.
    ///
    /// An existing run is never rewritten. Moving someone's start date would renumber every
    /// day they've already completed and invalidate their history, so a person who is
    /// already going keeps their journey and the pact records that the two aren't aligned.
    /// Saying that out loud beats silently destroying six weeks of someone's data.
    @discardableResult
    func accept(
        _ payload: PactInvitePayload,
        ownPeerID: String,
        existingJourney: Journey?,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> Pact {
        let store = FriendStore(modelContext: modelContext)
        _ = try store.addFriend(from: payload.card, ownPeerID: ownPeerID, nearby: false)

        let aligned: Bool
        if let existingJourney, existingJourney.isActive {
            aligned = calendar.isDate(
                calendar.startOfDay(for: existingJourney.startDate),
                inSameDayAs: calendar.startOfDay(for: payload.startDate)
            )
        } else {
            // A start date already in the past starts today rather than backdating days
            // the user never actually did.
            let start = max(calendar.startOfDay(for: payload.startDate), calendar.startOfDay(for: now))
            let journey = Journey(startDate: start, lengthInDays: payload.lengthInDays)
            modelContext.insert(journey)
            aligned = calendar.isDate(start, inSameDayAs: calendar.startOfDay(for: payload.startDate))
        }

        let pact = Pact(
            partnerPeerID: payload.card.peerID,
            partnerName: payload.card.displayName,
            startDate: payload.startDate,
            lengthInDays: payload.lengthInDays,
            startsAligned: aligned
        )
        modelContext.insert(pact)
        try modelContext.save()
        return pact
    }

    /// The partner's most recent shared update, for the side-by-side row.
    func latestUpdate(for pact: Pact) -> FriendUpdate? {
        let store = FriendStore(modelContext: modelContext)
        guard let friend = store.friend(peerID: pact.partnerPeerID) else { return nil }
        return friend.updates.sorted { $0.createdAt > $1.createdAt }.first
    }
}

/// Wraps an incoming invitation so it can drive a SwiftUI `sheet(item:)`.
struct PendingPact: Identifiable {
    let payload: PactInvitePayload
    var id: String { payload.card.peerID + payload.startDate.description }
}
