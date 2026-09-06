import Foundation
import StoreKit
import Observation

/// Product identifiers Fix Me offers. Kept centralized so App Store Connect
/// configuration and code stay in sync.
enum SubscriptionProduct: String, CaseIterable {
    case premiumYearly = "com.fixme.app.premium.yearly"
    case premiumMonthly = "com.fixme.app.premium.monthly"
    case premiumLifetime = "com.fixme.app.premium.lifetime"

    /// Display order on the paywall — yearly first, because it's the plan we want chosen.
    var sortOrder: Int {
        switch self {
        case .premiumYearly: return 0
        case .premiumMonthly: return 1
        case .premiumLifetime: return 2
        }
    }
}

/// What premium unlocks. Feature gates across the app reference these cases rather than
/// checking `isSubscribed` directly, so pricing/packaging can change in one place.
enum PremiumFeature: String {
    case unlimitedHabits
    case unlimitedAIVerification
    case premiumShareTemplates
    case advancedInsights
    case streakRepair
    case customChallenges
    case aiCoaching
}

/// StoreKit 2 purchase + entitlement layer. Nothing here simulates a purchase: on a
/// device without a configured store, `products` is simply empty and the app stays on
/// the free tier, which remains fully usable.
@MainActor
@Observable
final class SubscriptionService {
    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private(set) var isLoading = false
    private(set) var purchaseError: String?

    /// True when the user has never had an intro offer, so we can honestly say "7 days free".
    private(set) var isEligibleForIntroOffer = true

    private var updatesTask: Task<Void, Never>?

    init() {
        // Apple's guidance is to start listening for transaction updates at launch and
        // keep listening for the process lifetime, so this task is intentionally never
        // cancelled — dropping it could miss an Ask-to-Buy approval or a renewal.
        updatesTask = Task { [weak self] in await self?.observeTransactionUpdates() }
    }

    // MARK: - Catalog

    func loadProducts() async {
        guard products.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: SubscriptionProduct.allCases.map(\.rawValue))
            products = loaded.sorted { lhs, rhs in
                let l = SubscriptionProduct(rawValue: lhs.id)?.sortOrder ?? 99
                let r = SubscriptionProduct(rawValue: rhs.id)?.sortOrder ?? 99
                return l < r
            }
            await refreshIntroEligibility()
            await refreshEntitlements()
        } catch {
            products = []
        }
    }

    func product(for id: SubscriptionProduct) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    // MARK: - Purchase

    /// Returns true when the purchase completed and entitlement is now active.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "That purchase couldn't be verified."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return isSubscribed
            case .userCancelled:
                return false
            case .pending:
                purchaseError = "Your purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = "Couldn't complete that right now. You haven't been charged."
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            // Sync failing just means nothing to restore — entitlement check below is truth.
        }
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  SubscriptionProduct(rawValue: transaction.productID) != nil,
                  transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < .now { continue }
            active = true
        }
        isSubscribed = active
    }

    private func refreshIntroEligibility() async {
        guard let yearly = product(for: .premiumYearly),
              let subscription = yearly.subscription else {
            isEligibleForIntroOffer = false
            return
        }
        isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    // MARK: - Gating

    func isUnlocked(_ feature: PremiumFeature) -> Bool { isSubscribed }
}

// MARK: - Display helpers

extension Product {
    /// "$39.99 / year"
    var pricePerPeriodLabel: String {
        guard let period = subscription?.subscriptionPeriod else { return displayPrice }
        return "\(displayPrice) / \(period.unitLabel)"
    }

    /// Monthly-equivalent price for an annual plan, which is how buyers compare plans.
    var monthlyEquivalentLabel: String? {
        guard let period = subscription?.subscriptionPeriod, period.unit == .year else { return nil }
        let monthly = price / 12
        return monthly.formatted(.currency(code: priceFormatStyle.currencyCode)) + " / mo"
    }

    var hasFreeTrial: Bool {
        subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    var freeTrialLabel: String? {
        guard let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        return "\(offer.period.value) \(offer.period.unitLabel) free"
    }
}

extension Product.SubscriptionPeriod {
    var unitLabel: String {
        switch unit {
        case .day: return value == 1 ? "day" : "days"
        case .week: return value == 1 ? "week" : "weeks"
        case .month: return value == 1 ? "month" : "months"
        case .year: return value == 1 ? "year" : "years"
        @unknown default: return "period"
        }
    }
}
