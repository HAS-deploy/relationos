import XCTest
@testable import RelationOS

/// Source-level stand-in for the portfolio analytics-hard-gate. Catches
/// a dead PostHog wire (no start, no screens, no paywall events, or a
/// "Data Not Collected" privacy posture) before App Review.
final class AnalyticsHardGateTests: XCTestCase {

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func load(_ relativePath: String) throws -> String {
        try String(contentsOf: projectRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func testPostHogPackageIsLinked() throws {
        let yml = try load("project.yml")
        XCTAssertTrue(yml.contains("https://github.com/PostHog/posthog-ios"))
        XCTAssertTrue(yml.contains("product: PostHog"))
    }

    func testInfoPlistAndProjectDeclarePostHogKeyAndHost() throws {
        let plist = try load("RelationOS/Resources/Info.plist")
        let yml = try load("project.yml")
        XCTAssertTrue(plist.contains("PostHogKey"))
        XCTAssertTrue(plist.contains("PostHogHost"))
        XCTAssertTrue(plist.contains("phc_"))
        XCTAssertTrue(plist.contains("https://us.i.posthog.com"))
        XCTAssertTrue(yml.contains("PostHogKey"))
        XCTAssertTrue(yml.contains("PostHogHost"))
    }

    func testAppLaunchCallsPortfolioAnalyticsStart() throws {
        let source = try load("RelationOS/RelationOSApp.swift")
        XCTAssertTrue(source.contains("PortfolioAnalytics.shared.start(appName:"))
    }

    func testScreenViewedWiredOnMainScreens() throws {
        XCTAssertEqual(PortfolioEvent.screenViewed, "screen.viewed")
        let root = try load("RelationOS/App/RootView.swift")
        XCTAssertTrue(root.contains("trackScreen"))
        XCTAssertTrue(root.contains("\"contacts\""))
        XCTAssertTrue(root.contains("\"reconnect\""))
        XCTAssertTrue(root.contains("\"settings\""))
        let detail = try load("RelationOS/Features/ContactDetail/ContactDetailView.swift")
        XCTAssertTrue(detail.contains("trackScreen(\"contact_detail\")"))
        let paywall = try load("RelationOS/Features/Paywall/PaywallView.swift")
        XCTAssertTrue(paywall.contains("trackScreen(\"paywall\""))
    }

    func testPaywallViewedSuccessAndFailureAreEmitted() throws {
        let paywall = try load("RelationOS/Features/Paywall/PaywallView.swift")
        XCTAssertTrue(paywall.contains("PortfolioEvent.paywallViewed"))
        XCTAssertTrue(paywall.contains("PortfolioEvent.paywallPurchaseClick"))
        XCTAssertTrue(paywall.contains("PortfolioEvent.paywallPurchaseSuccess"))
        let purchases = try load("RelationOS/Core/Purchases/PurchaseManager.swift")
        XCTAssertTrue(purchases.contains("trackPaywallFailure"))
        XCTAssertTrue(purchases.contains(".productUnavailable"))
        XCTAssertTrue(purchases.contains("PortfolioEvent.restoreCompleted"))
    }

    func testOptOutIsHonoredAndSurfacedInSettings() throws {
        let analytics = try load("RelationOS/Core/Analytics/PortfolioAnalytics.swift")
        XCTAssertTrue(analytics.contains("portfolio.analytics.opted_out"))
        XCTAssertTrue(analytics.contains("guard started, !isOptedOut else { return }"))
        let settings = try load("RelationOS/Features/Settings/SettingsView.swift")
        XCTAssertTrue(settings.contains("Anonymous Usage Analytics"))
        XCTAssertTrue(settings.contains("optOut()"))
        XCTAssertTrue(settings.contains("optIn()"))
    }

    func testPrivacyManifestAndAnswersCollectAnalytics() throws {
        let privacy = try load("RelationOS/Resources/PrivacyInfo.xcprivacy")
        XCTAssertTrue(privacy.contains("NSPrivacyCollectedDataTypeProductInteraction"))
        XCTAssertTrue(privacy.contains("NSPrivacyCollectedDataTypeUserID"))
        XCTAssertTrue(privacy.contains("NSPrivacyCollectedDataTypeCrashData"))
        XCTAssertFalse(privacy.contains("NSPrivacyCollectedDataTypes</key>\n    <array/>"),
                       "PrivacyInfo must not declare an empty collected-data list")
        let answers = try load("docs/app-privacy-answers.md")
        XCTAssertTrue(answers.contains("Yes, we collect data"))
        XCTAssertFalse(answers.contains("For RelationOS: No, we do not collect data"))
        XCTAssertTrue(answers.contains("Product interaction"))
        XCTAssertTrue(answers.contains("User ID"))
    }
}
