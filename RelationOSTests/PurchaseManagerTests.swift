import XCTest
@testable import RelationOS

@MainActor
final class PurchaseManagerTests: XCTestCase {

    private let premiumKey = "relationos.isPremium"
    private let subscriptionKey = "relationos.hasActiveSubscription"
    private let installAtKey = "relationos.intro_trial.install_at"
    private let trialConsumedKey = "relationos.intro_trial.consumed"
    private var sharedDefaults: UserDefaults { ContactsStore.appGroupDefaults() }

    override func setUp() {
        super.setUp()
        flushDefaults()
    }

    override func tearDown() {
        flushDefaults()
        super.tearDown()
    }

    /// Premium state is mirrored to both the App Group suite (read by the
    /// widget) and `UserDefaults.standard` (legacy). Flush both so each
    /// test sees a clean slate. Also clears the install-trial stamp so
    /// the per-test PurchaseManager can deterministically be in or out
    /// of the trial window via the injected clock.
    private func flushDefaults() {
        for key in [premiumKey, subscriptionKey, installAtKey, trialConsumedKey,
                    "RELATIONOS_FORCE_PREMIUM"] {
            UserDefaults.standard.removeObject(forKey: key)
            sharedDefaults.removeObject(forKey: key)
        }
    }

    /// Trial clock pre-set to "already expired" so we can test the
    /// subscription-only paths without the install-trial granting Pro.
    private func expiredTrialClock() -> IntroTrialClock {
        let clock = IntroTrialClock(defaults: sharedDefaults)
        clock.recordInstallIfNeeded(now: Date(timeIntervalSince1970: 0))
        return clock
    }

    // MARK: - Subscription path (with the install trial bypassed)

    func testInitialIsPremiumFalse_whenTrialAlreadyExpired() {
        let pm = PurchaseManager(introTrial: expiredTrialClock())
        XCTAssertFalse(pm.isPremium)
        XCTAssertFalse(pm.hasActiveSubscription)
        XCTAssertFalse(pm.isInIntroTrial)
    }

    func testFallbackDisplayPricesWhenStoreKitProductsUnavailable() {
        let pm = PurchaseManager(introTrial: expiredTrialClock())
        XCTAssertEqual(pm.proMonthlyDisplayPrice, PricingConfig.fallbackProMonthlyDisplayPrice)
        XCTAssertEqual(pm.proAnnualDisplayPrice, PricingConfig.fallbackProAnnualDisplayPrice)
    }

    // MARK: - Install trial path

    func testFreshInstallGrantsTrialAndProForFourteenDays() {
        // No clock injection: PurchaseManager stamps installAt to "now"
        // and the user should immediately be Pro for the next 14 days.
        let pm = PurchaseManager()
        XCTAssertTrue(pm.isPremium, "Fresh install should land in the trial as Pro")
        XCTAssertTrue(pm.isInIntroTrial)
        XCTAssertFalse(pm.hasActiveSubscription)
        XCTAssertEqual(pm.introTrialDaysRemaining, 14)
        XCTAssertEqual(IntroTrialClock.length, 14 * 24 * 60 * 60)

        // Widget reads the composite from the App Group on first launch —
        // verify the stamp landed.
        XCTAssertTrue(sharedDefaults.bool(forKey: premiumKey))
    }

    func testRelaunchPreservesInstallStamp() {
        let pm1 = PurchaseManager()
        let stamp1 = sharedDefaults.object(forKey: installAtKey) as? Date
        XCTAssertNotNil(stamp1)
        XCTAssertTrue(pm1.isInIntroTrial)

        // Simulate relaunch — the install date must NOT advance.
        let pm2 = PurchaseManager()
        let stamp2 = sharedDefaults.object(forKey: installAtKey) as? Date
        XCTAssertEqual(stamp1, stamp2)
        XCTAssertTrue(pm2.isInIntroTrial)
    }

    #if DEBUG
    func testDebugRewindMovesUserCloserToTrialExpiry() {
        let pm = PurchaseManager()
        XCTAssertEqual(pm.introTrialDaysRemaining, 14)
        pm.debugRewindTrial(daysIn: 13)
        XCTAssertEqual(pm.introTrialDaysRemaining, 1)
        XCTAssertTrue(pm.isInIntroTrial)
        XCTAssertTrue(pm.isPremium)
    }

    func testDebugForceTrialExpiredRevertsToFree() {
        let pm = PurchaseManager()
        XCTAssertTrue(pm.isPremium)
        pm.debugForceTrialExpired()
        XCTAssertFalse(pm.isInIntroTrial)
        XCTAssertFalse(pm.isPremium)
    }

    func testPaidPurchaseConsumesInstallTrial() {
        let pm = PurchaseManager()
        XCTAssertTrue(pm.isInIntroTrial)
        XCTAssertEqual(pm.introTrialDaysRemaining, 14)
        pm.debugSetPremium(true)
        XCTAssertTrue(pm.hasActiveSubscription)
        XCTAssertTrue(pm.isPremium)
        XCTAssertFalse(pm.isInIntroTrial, "Paid purchase must consume the install trial")
        XCTAssertEqual(pm.introTrialDaysRemaining, 0)
    }

    func testDebugToggleFlipsOnlyTheSubscriptionBit() {
        // With trial expired we observe sub bit cleanly.
        let pm = PurchaseManager(introTrial: expiredTrialClock())
        XCTAssertFalse(pm.isPremium)
        pm.debugTogglePremium()
        XCTAssertTrue(pm.isPremium)
        XCTAssertTrue(pm.hasActiveSubscription)
        pm.debugTogglePremium()
        XCTAssertFalse(pm.isPremium)
        XCTAssertFalse(pm.hasActiveSubscription)
    }

    func testDebugSetSubscribedPersistsToUserDefaults() {
        let pm = PurchaseManager(introTrial: expiredTrialClock())
        pm.debugSetPremium(true)
        XCTAssertTrue(pm.isPremium)
        XCTAssertTrue(pm.hasActiveSubscription)
        // Composite key for the widget.
        XCTAssertTrue(sharedDefaults.bool(forKey: premiumKey))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: premiumKey))
        // Sub-only key.
        XCTAssertTrue(sharedDefaults.bool(forKey: subscriptionKey))

        // A fresh manager (with trial expired) picks up the persisted sub.
        let pm2 = PurchaseManager(introTrial: expiredTrialClock())
        XCTAssertTrue(pm2.hasActiveSubscription)
        XCTAssertTrue(pm2.isPremium)
    }
    #endif
}
