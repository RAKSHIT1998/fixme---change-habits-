import Foundation
import SwiftData

/// Two people who agreed to start their 90 days on the same day.
///
/// The referral loop asks someone to join *sometime*, which is a favour. This asks them to
/// start on a specific day alongside you, which is an appointment — and it makes the invite
/// functional rather than altruistic, because a shared start only exists if the other
/// person actually turns up. Accountability partners also finish more often, so the growth
/// mechanic and the product are the same thing here.
///
/// Both devices keep their own copy. There is no shared record anywhere, because there is
/// no server — what makes it feel joint is that the day numbers line up.
@Model
final class Pact {
    var id: UUID
    /// Peer ID of the other person, matching a `Friend`.
    var partnerPeerID: String
    var partnerName: String
    /// The day both journeys are meant to start. Day 1 for both sides.
    var startDate: Date
    var lengthInDays: Int
    var createdAt: Date
    /// False when the partner's own journey couldn't be aligned — they were already mid-run,
    /// so the pact is a shared intention rather than a shared day counter.
    var startsAligned: Bool

    init(
        id: UUID = UUID(),
        partnerPeerID: String,
        partnerName: String,
        startDate: Date,
        lengthInDays: Int = 90,
        createdAt: Date = .now,
        startsAligned: Bool = true
    ) {
        self.id = id
        self.partnerPeerID = partnerPeerID
        self.partnerName = partnerName
        self.startDate = startDate
        self.lengthInDays = lengthInDays
        self.createdAt = createdAt
        self.startsAligned = startsAligned
    }

    var hasStarted: Bool { Calendar.current.startOfDay(for: .now) >= Calendar.current.startOfDay(for: startDate) }

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: lengthInDays - 1, to: Calendar.current.startOfDay(for: startDate)) ?? startDate
    }

    /// Whether the shared run is over.
    ///
    /// Deliberately not derived from `dayNumber`, which clamps to `lengthInDays` for
    /// display and so can never report a day past the end — asking it "are we past 90?"
    /// always answers no.
    func isFinished(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: endDate)
    }

    /// Shared day number for display, or nil before the start date. Clamped to the length,
    /// so it reads "Day 90" rather than "Day 94" on an overrun.
    func dayNumber(on date: Date = .now, calendar: Calendar = .current) -> Int? {
        let start = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: date)
        guard target >= start else { return nil }
        let days = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        return min(days + 1, lengthInDays)
    }

    func daysUntilStart(from date: Date = .now, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let today = calendar.startOfDay(for: date)
        return max(calendar.dateComponents([.day], from: today, to: start).day ?? 0, 0)
    }
}

/// What travels in a "start with me" link.
///
/// Carries the sender's identity card so accepting pairs the two devices in the same step —
/// the alternative is asking someone to accept an invite and then separately add a friend,
/// which is where people drop out. Self-attesting exactly like a plain pairing invite:
/// trust is established when the recipient accepts, not by this payload.
struct PactInvitePayload: Codable {
    let card: IdentityCard
    let startDate: Date
    let lengthInDays: Int
    let message: String?
}
