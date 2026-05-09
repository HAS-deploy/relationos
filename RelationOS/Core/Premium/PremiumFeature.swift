import Foundation

/// Feature keys that can be gated behind premium. Each rawValue is the
/// canonical analytics trigger source string the paywall emits when fired
/// from this feature.
///
/// v1 trim: AI meeting notes and semantic search are deferred to v1.1 and
/// are not advertised; their enum cases were removed. Smart-context
/// reminders are deferred too — v1 ships only the contact-cap uplift and
/// the Daily Reconnect view (with cooling-relationships sort).
enum PremiumFeature: String, Identifiable, Hashable {
    case unlimitedContacts
    case dailyReconnect
    case coolingRelationships

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unlimitedContacts:    return "Unlimited Contacts"
        case .dailyReconnect:       return "Daily Reconnect"
        case .coolingRelationships: return "Cooling Relationships"
        }
    }
}

/// Lightweight gate used by views and unit tests so paywall, UI, and tests
/// agree on what's free vs. paid. The free tier allows all listed features
/// to *appear* but caps unlimited usage; the paywall fires when the cap is
/// reached or a premium-only feature is opened.
struct PremiumGate {
    let isPremium: Bool

    /// Is this feature available without paying? Daily Reconnect and the
    /// cooling-relationships highlighted view are premium-only. Free
    /// users see locked previews.
    func isAllowed(_ feature: PremiumFeature) -> Bool {
        if isPremium { return true }
        switch feature {
        case .unlimitedContacts:
            // Free tier: capped to PricingConfig.freeContactCap. Caller
            // should check canAddAnotherContact(currentCount:) instead.
            return false
        case .dailyReconnect, .coolingRelationships:
            return false
        }
    }

    /// Free users can add contacts up to the cap; premium is unlimited.
    func canAddAnotherContact(currentCount: Int) -> Bool {
        if isPremium { return true }
        return currentCount < PricingConfig.freeContactCap
    }
}
