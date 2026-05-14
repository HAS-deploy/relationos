import Foundation

/// Single source of truth for pricing. Update values here, not scattered.
/// Product IDs must match App Store Connect and Configuration.storekit.
enum PricingConfig {
    static let proMonthlyProductID = "app.relationos.pro.monthly"
    static let proAnnualProductID  = "app.relationos.pro.annual"
    static let subscriptionGroupID = "relationos_pro"

    static let fallbackProMonthlyDisplayPrice = "$11.99"
    static let fallbackProAnnualDisplayPrice  = "$89.99"

    static let allProductIDs: [String] = [proMonthlyProductID, proAnnualProductID]

    static let paywallTitle    = "Unlock RelationOS Pro"
    /// Subtitle is copy shown above the plan picker. The install-trial
    /// granted at first launch is independent of the subscription, so we
    /// no longer advertise a per-product free trial — see PaywallView for
    /// the "X days of Pro free remaining" banner that runs separately.
    static let paywallSubtitle = "Unlimited contacts and daily reconnect. Cancel anytime."

    static let paywallBenefits: [String] = [
        "Unlimited contacts",
        "Daily reconnect list — 5 people every morning",
        "Cooling relationships highlighted",
        "Daily reconnect widget shows your Pro list",
    ]

    // Free-tier caps.
    static let freeContactCap = 100

    // Marketing URLs (also referenced from PaywallView for legal links).
    // Hosted on GitHub Pages (HAS-deploy/relationos, /docs on main).
    static let privacyPolicyURL = URL(string: "https://has-deploy.github.io/relationos/privacy")!
    static let termsOfUseURL    = URL(string: "https://has-deploy.github.io/relationos/terms")!
}
