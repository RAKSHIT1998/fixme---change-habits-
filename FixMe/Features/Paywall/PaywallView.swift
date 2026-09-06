import SwiftUI
import StoreKit

/// The purchase screen. Structure follows what converts in this category: contextual
/// headline → the payoff → plan choice with the annual plan pre-selected and anchored
/// against monthly → one unmistakable CTA → honest trial/renewal terms directly under it.
struct PaywallView: View {
    let trigger: PaywallTrigger
    var onPurchased: (() -> Void)? = nil

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var showRestoreResult = false
    @State private var legalDocument: LegalDocument?

    private var subscriptions: SubscriptionService { services.subscriptions }

    private var selectedProduct: Product? {
        subscriptions.products.first { $0.id == selectedProductID }
            ?? subscriptions.product(for: .premiumYearly)
            ?? subscriptions.products.first
    }

    var body: some View {
        ZStack {
            FMTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: FMTheme.Spacing.lg) {
                    header
                    featureList
                    planPicker
                }
                .padding(.horizontal, FMTheme.Spacing.lg)
                .padding(.top, FMTheme.Spacing.xl)
                .padding(.bottom, 220)
            }

            VStack {
                Spacer()
                purchaseFooter
            }
        }
        .overlay(alignment: .topTrailing) { closeButton }
        .task {
            await subscriptions.loadProducts()
            if selectedProductID == nil {
                selectedProductID = subscriptions.product(for: .premiumYearly)?.id
                    ?? subscriptions.products.first?.id
            }
            services.analytics.track(.paywallViewed(trigger: trigger.rawValue))
        }
        .sheet(item: $legalDocument) { LegalDocumentView(document: $0) }
        .alert("Purchases restored", isPresented: $showRestoreResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(subscriptions.isSubscribed
                 ? "You're all set — Premium is active."
                 : "We didn't find an active subscription on this Apple Account.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: FMTheme.Spacing.sm) {
            Text("⚡️").font(.system(size: 48))

            Text(trigger.headline)
                .font(FMTheme.Typography.display(32))
                .multilineTextAlignment(.center)
                .foregroundStyle(FMTheme.Colors.textPrimary)

            Text(trigger.subheadline)
                .font(FMTheme.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(FMTheme.Colors.textSecondary)
                .padding(.horizontal, FMTheme.Spacing.sm)
        }
    }

    private var featureList: some View {
        VStack(spacing: FMTheme.Spacing.xs) {
            ForEach(PremiumFeature.paywallOrder, id: \.self) { feature in
                PaywallFeatureRow(
                    feature: feature,
                    isEmphasized: feature == trigger.emphasizedFeature
                )
            }
        }
    }

    @ViewBuilder
    private var planPicker: some View {
        VStack(spacing: FMTheme.Spacing.xs) {
            if subscriptions.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FMTheme.Spacing.lg)
            } else if subscriptions.products.isEmpty {
                // Store unreachable, or no products configured yet. Never leave the user
                // staring at a spinner — say what happened and let them retry or leave.
                VStack(spacing: FMTheme.Spacing.sm) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 26))
                        .foregroundStyle(FMTheme.Colors.textTertiary)
                    Text("Couldn't load plans right now.")
                        .font(FMTheme.Typography.subheadline)
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    Text("Your habits are all still here — you can keep going on the free plan.")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Try again") {
                        Task { await subscriptions.loadProducts() }
                    }
                    .font(FMTheme.Typography.subheadline)
                    .foregroundStyle(FMTheme.Colors.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(FMTheme.Spacing.lg)
                .background(FMTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
            } else {
                ForEach(subscriptions.products, id: \.id) { product in
                    PlanOptionRow(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        savingsBadge: savingsBadge(for: product)
                    ) {
                        Haptics.selection()
                        selectedProductID = product.id
                    }
                }
            }
        }
    }

    private var purchaseFooter: some View {
        VStack(spacing: FMTheme.Spacing.xs) {
            FMPrimaryButton(
                title: ctaTitle,
                icon: "arrow.right",
                isLoading: isPurchasing
            ) {
                guard selectedProduct != nil else { dismiss(); return }
                Task { await purchase() }
            }

            Text(termsLine)
                .font(.system(size: 11))
                .foregroundStyle(FMTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: FMTheme.Spacing.md) {
                Button("Restore") {
                    Task {
                        await subscriptions.restorePurchases()
                        showRestoreResult = true
                        if subscriptions.isSubscribed { onPurchased?(); dismiss() }
                    }
                }
                Button("Terms") { legalDocument = .terms }
                Button("Privacy") { legalDocument = .privacy }
            }
            .font(.system(size: 11))
            .foregroundStyle(FMTheme.Colors.textTertiary)

            if let error = subscriptions.purchaseError {
                Text(error)
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.danger)
            }
        }
        .padding(.horizontal, FMTheme.Spacing.lg)
        .padding(.top, FMTheme.Spacing.md)
        .padding(.bottom, FMTheme.Spacing.md)
        .background(.ultraThinMaterial)
    }

    private var closeButton: some View {
        Button {
            services.analytics.track(.paywallDismissed(trigger: trigger.rawValue))
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FMTheme.Colors.textTertiary)
                .frame(width: 30, height: 30)
                .background(FMTheme.Colors.surface, in: Circle())
        }
        .padding(FMTheme.Spacing.md)
    }

    // MARK: - Copy

    private var ctaTitle: String {
        guard let product = selectedProduct else { return "Continue with Free" }
        if product.hasFreeTrial && subscriptions.isEligibleForIntroOffer {
            return "Start 7 days free"
        }
        return "Unlock Premium"
    }

    /// Apple requires the renewal terms be clear and adjacent to the CTA — and vague
    /// trial copy is the #1 driver of refunds and chargebacks, so this stays explicit.
    private var termsLine: String {
        guard let product = selectedProduct else { return "" }
        if product.hasFreeTrial && subscriptions.isEligibleForIntroOffer {
            return "7 days free, then \(product.pricePerPeriodLabel). Cancel anytime in Settings."
        }
        if product.subscription == nil {
            return "\(product.displayPrice) once. Yours forever."
        }
        return "\(product.pricePerPeriodLabel). Renews automatically. Cancel anytime."
    }

    private func savingsBadge(for product: Product) -> String? {
        guard product.subscription?.subscriptionPeriod.unit == .year,
              let monthly = subscriptions.product(for: .premiumMonthly) else { return nil }
        let yearlyIfMonthly = monthly.price * 12
        guard yearlyIfMonthly > 0 else { return nil }
        let savings = (1 - (product.price / yearlyIfMonthly)) * 100
        guard savings > 5 else { return nil }
        return "SAVE \(NSDecimalNumber(decimal: savings).intValue)%"
    }

    // MARK: - Actions

    private func purchase() async {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        services.analytics.track(.checkoutStarted(productID: product.id))
        let success = await subscriptions.purchase(product)
        if success {
            Haptics.notify(.success)
            services.analytics.track(
                .subscriptionStarted(productID: product.id, isTrial: product.hasFreeTrial)
            )
            onPurchased?()
            dismiss()
        }
    }
}

// MARK: - Rows

private struct PaywallFeatureRow: View {
    let feature: PremiumFeature
    let isEmphasized: Bool

    var body: some View {
        HStack(spacing: FMTheme.Spacing.sm) {
            Image(systemName: feature.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isEmphasized ? .white : FMTheme.Colors.accent)
                .frame(width: 34, height: 34)
                .background(
                    isEmphasized ? FMTheme.Colors.accent : FMTheme.Colors.accent.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(feature.title)
                    .font(FMTheme.Typography.subheadline)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
                Text(feature.detail)
                    .font(FMTheme.Typography.footnote)
                    .foregroundStyle(FMTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(FMTheme.Spacing.sm)
        .background(isEmphasized ? FMTheme.Colors.accent.opacity(0.08) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
    }
}

private struct PlanOptionRow: View {
    let product: Product
    let isSelected: Bool
    let savingsBadge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FMTheme.Spacing.sm) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? FMTheme.Colors.accent : FMTheme.Colors.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(planTitle)
                            .font(FMTheme.Typography.headline)
                            .foregroundStyle(FMTheme.Colors.textPrimary)
                        if let savingsBadge {
                            Text(savingsBadge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(FMTheme.Colors.accent, in: Capsule())
                        }
                    }
                    Text(planSubtitle)
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                Text(product.displayPrice)
                    .font(FMTheme.Typography.headline)
                    .foregroundStyle(FMTheme.Colors.textPrimary)
            }
            .padding(FMTheme.Spacing.md)
            .background(FMTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous)
                    .stroke(isSelected ? FMTheme.Colors.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(FMTheme.Motion.snappy, value: isSelected)
    }

    private var planTitle: String {
        guard let period = product.subscription?.subscriptionPeriod else { return "Lifetime" }
        return period.unit == .year ? "Yearly" : "Monthly"
    }

    private var planSubtitle: String {
        if product.subscription == nil { return "One payment, forever" }
        if let trial = product.freeTrialLabel { return "\(trial), then \(product.pricePerPeriodLabel)" }
        if let monthly = product.monthlyEquivalentLabel { return monthly }
        return product.pricePerPeriodLabel
    }
}

#Preview("Onboarding") {
    PaywallView(trigger: .onboardingComplete)
}

#Preview("Streak repair") {
    PaywallView(trigger: .streakRepair)
}
