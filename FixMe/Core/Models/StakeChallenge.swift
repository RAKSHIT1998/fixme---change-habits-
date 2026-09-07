import Foundation
import SwiftData

/// A 90-day commitment with something staked on it.
///
/// The mechanic is old and well-evidenced: people finish far more often when failing costs
/// them something they can name. What makes it work is that the rule is *harsh and
/// unambiguous* — one missed day ends it, no freezes, no repair, no negotiating with
/// yourself at 11pm. Softening that is the same as removing it.
///
/// **The app never touches the money.** It records what you pledged and who is holding you
/// to it; settling up happens between you and your referee. StoreKit cannot refund a
/// purchase programmatically — Apple controls refunds — and holding stakes on a contingent
/// outcome is a wager, which needs a backend, licensing and legal review this app has
/// none of. So the stake here is a promise with a witness, not an escrow account.
@Model
final class StakeChallenge {
    var id: UUID
    var startDate: Date
    var lengthInDays: Int

    /// What the user says they're putting on it, in their own currency. Never charged.
    var stakeAmount: Double
    var stakeCurrencyCode: String
    /// Free text: who or what collects if they fail ("Sam", "the dog shelter").
    var stakeHolder: String

    /// Optional friend acting as referee, from the existing peer-to-peer friend list.
    var refereePeerID: String?
    var refereeName: String?

    var outcomeRaw: String
    var failedOnDay: Int?
    var resolvedAt: Date?
    /// Recorded because the terms are deliberately unforgiving; the user has to have seen them.
    var acceptedTermsAt: Date

    var journey: Journey?

    init(
        id: UUID = UUID(),
        startDate: Date = Calendar.current.startOfDay(for: .now),
        lengthInDays: Int = 90,
        stakeAmount: Double = 50,
        stakeCurrencyCode: String = Locale.current.currency?.identifier ?? "USD",
        stakeHolder: String = "",
        refereePeerID: String? = nil,
        refereeName: String? = nil,
        outcome: StakeOutcome = .active,
        acceptedTermsAt: Date = .now
    ) {
        self.id = id
        self.startDate = startDate
        self.lengthInDays = lengthInDays
        self.stakeAmount = stakeAmount
        self.stakeCurrencyCode = stakeCurrencyCode
        self.stakeHolder = stakeHolder
        self.refereePeerID = refereePeerID
        self.refereeName = refereeName
        self.outcomeRaw = outcome.rawValue
        self.acceptedTermsAt = acceptedTermsAt
    }

    var outcome: StakeOutcome {
        get { StakeOutcome(rawValue: outcomeRaw) ?? .active }
        set { outcomeRaw = newValue.rawValue }
    }

    var isActive: Bool { outcome == .active }

    var formattedStake: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = stakeCurrencyCode
        formatter.maximumFractionDigits = stakeAmount == stakeAmount.rounded() ? 0 : 2
        return formatter.string(from: NSNumber(value: stakeAmount)) ?? "\(Int(stakeAmount))"
    }
}

enum StakeOutcome: String, Codable {
    case active, won, lost
}
