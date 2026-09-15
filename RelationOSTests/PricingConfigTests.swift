import XCTest
@testable import RelationOS

final class PricingConfigTests: XCTestCase {

    func testProductIDsLockedToSpec() {
        XCTAssertEqual(PricingConfig.proMonthlyProductID, "app.relationos.pro.monthly")
        XCTAssertEqual(PricingConfig.proAnnualProductID,  "app.relationos.pro.annual")
    }

    func testSubscriptionGroupIDLockedToSpec() {
        XCTAssertEqual(PricingConfig.subscriptionGroupID, "relationos_pro")
    }

    func testAllProductIDsContainsBothSubscriptions() {
        XCTAssertTrue(PricingConfig.allProductIDs.contains(PricingConfig.proMonthlyProductID))
        XCTAssertTrue(PricingConfig.allProductIDs.contains(PricingConfig.proAnnualProductID))
        XCTAssertEqual(PricingConfig.allProductIDs.count, 2)
    }

    func testFallbackDisplayPricesMatchSpec() {
        XCTAssertEqual(PricingConfig.fallbackProMonthlyDisplayPrice, "$11.99")
        XCTAssertEqual(PricingConfig.fallbackProAnnualDisplayPrice,  "$89.99")
    }

    func testFreeTierContactCap() {
        XCTAssertEqual(PricingConfig.freeContactCap, 100)
    }

    func testInstallTrialDaysMatchesPortfolioPolicy() {
        XCTAssertEqual(PricingConfig.installTrialDays, 14)
    }

    func testPaywallTitleAndSubtitleMatchSpec() {
        // 2026-05-14: Trial model changed from "free trial on subscribe"
        // to "Pro free for 14 days from install" (see IntroTrialClock).
        // Subtitle no longer advertises the trial — the in-paywall banner
        // surfaces it conditionally based on `purchases.isInIntroTrial`.
        XCTAssertEqual(PricingConfig.paywallTitle, "Unlock RelationOS Pro")
        XCTAssertEqual(PricingConfig.paywallSubtitle, "Unlimited contacts and daily reconnect. Cancel anytime.")
    }

    func testPaywallBenefitsMatchTrimmedV1Scope() {
        // v1 trim (2026-05-07): AI meeting notes / semantic search / smart
        // reminders / decay detection are deferred to v1.1 and not
        // advertised here. Benefits must match what the StoreKit
        // subscription descriptions advertise so audits stay consistent.
        XCTAssertEqual(PricingConfig.paywallBenefits.count, 4)
        XCTAssertTrue(PricingConfig.paywallBenefits.contains("Unlimited contacts"))
        XCTAssertTrue(PricingConfig.paywallBenefits.contains("Daily reconnect list — 5 people every morning"))
        XCTAssertTrue(PricingConfig.paywallBenefits.contains("Cooling relationships highlighted"))
        XCTAssertTrue(PricingConfig.paywallBenefits.contains("Daily reconnect widget shows your Pro list"))
        // Negative checks: removed claims must not creep back in.
        XCTAssertFalse(PricingConfig.paywallBenefits.contains("Smart reminders"))
        XCTAssertFalse(PricingConfig.paywallBenefits.contains("Decay detection"))
        XCTAssertFalse(PricingConfig.paywallBenefits.contains("Semantic search"))
        XCTAssertFalse(PricingConfig.paywallBenefits.contains("AI meeting notes"))
    }

    func testLegalLinksMatchSpec() {
        XCTAssertEqual(PricingConfig.privacyPolicyURL.absoluteString,
                       "https://has-deploy.github.io/relationos/privacy")
        XCTAssertEqual(PricingConfig.termsOfUseURL.absoluteString,
                       "https://has-deploy.github.io/relationos/terms")
    }

    func testPremiumGateFreeContactCap() {
        let free = PremiumGate(isPremium: false)
        XCTAssertTrue(free.canAddAnotherContact(currentCount: 0))
        XCTAssertTrue(free.canAddAnotherContact(currentCount: PricingConfig.freeContactCap - 1))
        XCTAssertFalse(free.canAddAnotherContact(currentCount: PricingConfig.freeContactCap))
        XCTAssertFalse(free.canAddAnotherContact(currentCount: 999))

        let pro = PremiumGate(isPremium: true)
        XCTAssertTrue(pro.canAddAnotherContact(currentCount: 100_000))
    }
}
