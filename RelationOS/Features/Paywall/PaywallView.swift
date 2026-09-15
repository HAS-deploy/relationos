import SwiftUI

/// IMPORTANT — App Store Guideline 3.1.2(a) compliance.
///
/// The four disclosure sentences below MUST appear verbatim in the rendered
/// paywall. They are stored here as static `String` constants so:
///   1. The paywall view can render them directly.
///   2. `PaywallDisclosureTests` can load this source file and grep for
///      each sentence as a regression guard against future edits.
/// Do NOT translate, summarize, or split these strings without first
/// updating `docs/paywall-disclosure-check.md` and re-running
/// `paywall-hard-gate.py`.
enum PaywallDisclosure {
    static let chargedAtConfirmation =
        "Payment will be charged to your Apple ID account at confirmation of purchase."
    static let autoRenewUnlessCanceled =
        "Subscription automatically renews unless canceled at least 24 hours before the end of the current period."
    static let chargedForRenewal =
        "Your account will be charged for renewal within 24 hours prior to the end of the current period."
    static let manageInAccountSettings =
        "Subscriptions may be managed and auto-renewal may be turned off by going to the user's Account Settings after purchase."

    static let all: [String] = [
        chargedAtConfirmation,
        autoRenewUnlessCanceled,
        chargedForRenewal,
        manageInAccountSettings,
    ]
}

struct PaywallView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics

    let triggeringFeature: PremiumFeature

    enum Plan: Hashable { case monthly, annual }

    /// Default to annual per spec (paywall highlights "Save 37%").
    @State private var selectedPlan: Plan = .annual

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if purchases.isInIntroTrial {
                        introTrialBanner
                    }
                    benefits
                    planPicker
                    purchaseButton
                    restoreButton
                    if let error = purchases.lastError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    legalFooter
                }
                .padding()
            }
            .navigationTitle(PricingConfig.paywallTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            analytics.track(.paywallViewed, properties: ["feature": triggeringFeature.rawValue])
            PortfolioAnalytics.shared.trackScreen("paywall", extras: [
                "source": triggeringFeature.rawValue,
            ])
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallViewed, [
                "source": triggeringFeature.rawValue,
            ])
        }
        .onChange(of: purchases.isPremium) { newValue in
            if newValue { dismiss() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "person.2.crop.square.stack.fill")
                .font(.system(size: 42))
                .foregroundStyle(Theme.accent)
            Text(PricingConfig.paywallTitle).font(.largeTitle.bold())
            Text(PricingConfig.paywallSubtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    /// In-trial users see this above the plan picker so they understand
    /// why they're being asked to subscribe even though Pro currently
    /// works for them — and how long until that ends.
    private var introTrialBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("You're on Pro free, \(purchases.introTrialDaysRemaining)-day\(purchases.introTrialDaysRemaining == 1 ? "" : "s") left")
                    .font(.subheadline.bold())
                Text("Subscribe any time before the trial ends to keep your full Daily Reconnect list and unlimited contacts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.accent.opacity(0.1))
        )
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(PricingConfig.paywallBenefits, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    Text(item)
                }.font(.body)
            }
        }
    }

    private var planPicker: some View {
        VStack(spacing: 12) {
            planCard(
                plan: .annual,
                title: "RelationOS Pro — Annual",
                length: "Annual",
                priceLine: "\(purchases.proAnnualDisplayPrice) / year",
                microcopy: planMicrocopy(annual: true),
                badge: "Save 37%"
            )
            planCard(
                plan: .monthly,
                title: "RelationOS Pro — Monthly",
                length: "Monthly",
                priceLine: "\(purchases.proMonthlyDisplayPrice) / month",
                microcopy: planMicrocopy(annual: false),
                badge: nil
            )
        }
    }

    /// In-trial: "Starts when your trial ends". Post-trial: just the
    /// per-period billing reminder. The 14-day free chunk is the install
    /// grant, never the subscription's introductoryOffer — so no trial
    /// microcopy on the cards.
    private func planMicrocopy(annual: Bool) -> String {
        if purchases.isInIntroTrial {
            let n = purchases.introTrialDaysRemaining
            return "Starts after your \(n)-day Pro trial ends"
        }
        return annual ? "Billed yearly" : "Billed monthly"
    }

    private func planCard(
        plan: Plan,
        title: String,
        length: String,
        priceLine: String,
        microcopy: String,
        badge: String?
    ) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            selectedPlan = plan
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.accent.opacity(0.15))
                                .foregroundStyle(Theme.accent)
                                .clipShape(Capsule())
                        }
                    }
                    Text(length).font(.caption).foregroundStyle(.secondary)
                    Text(priceLine).font(.subheadline.monospacedDigit())
                    Text(microcopy).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(isSelected ? Theme.accent : Color(.separator), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var purchaseButton: some View {
        Button {
            let productId = (selectedPlan == .annual)
                ? PricingConfig.proAnnualProductID
                : PricingConfig.proMonthlyProductID
            analytics.track(.purchaseStarted, properties: [
                "product": selectedPlan == .annual ? "annual" : "monthly",
            ])
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseClick, [
                "source": triggeringFeature.rawValue,
                "product_id": productId,
            ])
            Task {
                let before = purchases.isPremium
                if selectedPlan == .annual {
                    await purchases.purchaseAnnual()
                } else {
                    await purchases.purchaseMonthly()
                }
                if purchases.isPremium && !before {
                    analytics.track(.purchaseCompleted, properties: [
                        "product": selectedPlan == .annual ? "annual" : "monthly",
                    ])
                    PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseSuccess, [
                        "is_sub": true,
                        "source": triggeringFeature.rawValue,
                        "product_id": productId,
                    ])
                }
            }
        } label: {
            HStack {
                if purchases.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(purchaseButtonTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16).padding(.horizontal, 16)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(purchases.isPurchasing)
    }

    private var purchaseButtonTitle: String {
        if purchases.isInIntroTrial {
            return selectedPlan == .annual ? "Continue annually" : "Continue monthly"
        }
        return selectedPlan == .annual ? "Subscribe annually" : "Subscribe monthly"
    }

    private var restoreButton: some View {
        Button {
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallRestoreClick)
            Task {
                await purchases.restorePurchases()
                if purchases.isPremium { analytics.track(.purchaseRestored) }
            }
        } label: {
            Text("Restore Purchases").font(.subheadline).foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
    }

    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The four mandatory 3.1.2(a) disclosure sentences. Rendered
            // verbatim from PaywallDisclosure constants. Do not edit copy
            // here without also updating those constants and re-running
            // paywall-hard-gate.py.
            Text(PaywallDisclosure.chargedAtConfirmation)
            Text(PaywallDisclosure.autoRenewUnlessCanceled)
            Text(PaywallDisclosure.chargedForRenewal)
            Text(PaywallDisclosure.manageInAccountSettings)

            HStack(spacing: 12) {
                Link("Privacy Policy", destination: PricingConfig.privacyPolicyURL)
                Text("·")
                Link("Terms of Use", destination: PricingConfig.termsOfUseURL)
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.subtle)
    }
}
