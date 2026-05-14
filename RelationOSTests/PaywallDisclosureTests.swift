import XCTest
@testable import RelationOS

/// Guards against future edits removing required 3.1.2(a) disclosures from
/// the paywall. Loads `Features/Paywall/PaywallView.swift` from disk via the
/// `#filePath` of this test file (which is two directories above
/// `Features/`) and asserts every required sentence appears verbatim.
///
/// Why source-as-string and not just inspect the SwiftUI view tree?
/// Reviewers grep the binary for these sentences. Catching a missing
/// sentence at the source level is the cheapest possible regression guard
/// and removes any chance of conditional rendering hiding it from review.
final class PaywallDisclosureTests: XCTestCase {

    /// Computes /path/to/relationos/RelationOS/Features/Paywall/PaywallView.swift
    /// from this test file's location.
    private var paywallSourcePath: String {
        // #filePath = .../relationos/RelationOSTests/PaywallDisclosureTests.swift
        let testFile = URL(fileURLWithPath: #filePath)
        let testsDir = testFile.deletingLastPathComponent()
        let projectRoot = testsDir.deletingLastPathComponent()
        return projectRoot
            .appendingPathComponent("RelationOS")
            .appendingPathComponent("Features")
            .appendingPathComponent("Paywall")
            .appendingPathComponent("PaywallView.swift")
            .path
    }

    private func loadPaywallSource() throws -> String {
        try String(contentsOfFile: paywallSourcePath, encoding: .utf8)
    }

    func testPaywallSourceFileExists() throws {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: paywallSourcePath),
            "Expected paywall source at \(paywallSourcePath)"
        )
    }

    func testPaywallSourceContainsAllFourMandatorySentences() throws {
        let source = try loadPaywallSource()

        // Required verbatim under App Store Guideline 3.1.2(a).
        let mandatory = [
            "Payment will be charged to your Apple ID account at confirmation of purchase.",
            "Subscription automatically renews unless canceled at least 24 hours before the end of the current period.",
            "Your account will be charged for renewal within 24 hours prior to the end of the current period.",
            "Subscriptions may be managed and auto-renewal may be turned off by going to the user's Account Settings after purchase.",
        ]
        for sentence in mandatory {
            XCTAssertTrue(
                source.contains(sentence),
                "Paywall source must contain verbatim 3.1.2(a) sentence: \"\(sentence)\""
            )
        }
    }

    func testPaywallSourceContainsSubscriptionTitleAndLength() throws {
        let source = try loadPaywallSource()
        // Subscription titles
        XCTAssertTrue(source.contains("RelationOS Pro — Monthly"),
                      "Paywall must show monthly subscription title")
        XCTAssertTrue(source.contains("RelationOS Pro — Annual"),
                      "Paywall must show annual subscription title")
        // Subscription length labels
        XCTAssertTrue(source.contains("Monthly"), "Paywall must label monthly length")
        XCTAssertTrue(source.contains("Annual"), "Paywall must label annual length")
    }

    func testPaywallSourceRendersPricesFromPurchaseManager() throws {
        let source = try loadPaywallSource()
        // Prices come from PurchaseManager (StoreKit display price + fallback).
        XCTAssertTrue(source.contains("purchases.proMonthlyDisplayPrice"),
                      "Paywall must render monthly price from PurchaseManager")
        XCTAssertTrue(source.contains("purchases.proAnnualDisplayPrice"),
                      "Paywall must render annual price from PurchaseManager")
    }

    func testPaywallSourceContainsTappablePrivacyAndTermsLinks() throws {
        let source = try loadPaywallSource()
        // We use Link() on URL constants from PricingConfig.
        XCTAssertTrue(source.contains("PricingConfig.privacyPolicyURL"),
                      "Paywall must link to Privacy Policy URL")
        XCTAssertTrue(source.contains("PricingConfig.termsOfUseURL"),
                      "Paywall must link to Terms of Use URL")
        XCTAssertTrue(source.contains("Privacy Policy"),
                      "Paywall must label the privacy link \"Privacy Policy\"")
        XCTAssertTrue(source.contains("Terms of Use"),
                      "Paywall must label the terms link \"Terms of Use\"")

        // The URLs themselves must point at the GitHub Pages host (sanity check).
        XCTAssertEqual(PricingConfig.privacyPolicyURL.host, "has-deploy.github.io")
        XCTAssertEqual(PricingConfig.termsOfUseURL.host, "has-deploy.github.io")
        XCTAssertTrue(PricingConfig.privacyPolicyURL.path.hasPrefix("/relationos/"))
        XCTAssertTrue(PricingConfig.termsOfUseURL.path.hasPrefix("/relationos/"))
    }

    func testPaywallSourceContainsRestorePurchasesButton() throws {
        let source = try loadPaywallSource()
        XCTAssertTrue(source.contains("Restore Purchases"),
                      "Paywall must show a visible Restore Purchases button")
    }

    func testPaywallSourceSurfacesInstallTrialBanner() throws {
        // 2026-05-14: The 14-day trial is granted at install (see
        // IntroTrialClock), not by tapping a subscription plan. The paywall
        // surfaces it through a conditional banner gated on
        // `purchases.isInIntroTrial`, with a per-plan microcopy line that
        // also varies on that flag.
        let source = try loadPaywallSource()
        XCTAssertTrue(source.contains("purchases.isInIntroTrial"),
                      "Paywall must branch trial copy on purchases.isInIntroTrial")
        XCTAssertTrue(source.contains("introTrialDaysRemaining"),
                      "Paywall must show the install-trial day counter")
        XCTAssertTrue(source.contains("Starts after your"),
                      "Plan card microcopy must surface the install-trial expiry")
    }

    func testPaywallDisclosureConstantsListAllFour() {
        // Tighter check on the typed constants the view renders.
        XCTAssertEqual(PaywallDisclosure.all.count, 4)
        XCTAssertTrue(PaywallDisclosure.all.contains(
            "Payment will be charged to your Apple ID account at confirmation of purchase."))
        XCTAssertTrue(PaywallDisclosure.all.contains(
            "Subscription automatically renews unless canceled at least 24 hours before the end of the current period."))
        XCTAssertTrue(PaywallDisclosure.all.contains(
            "Your account will be charged for renewal within 24 hours prior to the end of the current period."))
        XCTAssertTrue(PaywallDisclosure.all.contains(
            "Subscriptions may be managed and auto-renewal may be turned off by going to the user's Account Settings after purchase."))
    }
}
