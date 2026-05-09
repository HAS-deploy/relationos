import XCTest
@testable import RelationOS

@MainActor
final class PurchaseManagerTests: XCTestCase {

    private let premiumKey = "relationos.isPremium"
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
    /// test sees a clean slate.
    private func flushDefaults() {
        UserDefaults.standard.removeObject(forKey: premiumKey)
        UserDefaults.standard.removeObject(forKey: "RELATIONOS_FORCE_PREMIUM")
        sharedDefaults.removeObject(forKey: premiumKey)
        sharedDefaults.removeObject(forKey: "RELATIONOS_FORCE_PREMIUM")
    }

    func testInitialIsPremiumFalse() {
        let pm = PurchaseManager()
        XCTAssertFalse(pm.isPremium)
    }

    func testFallbackDisplayPricesWhenStoreKitProductsUnavailable() {
        let pm = PurchaseManager()
        XCTAssertEqual(pm.proMonthlyDisplayPrice, PricingConfig.fallbackProMonthlyDisplayPrice)
        XCTAssertEqual(pm.proAnnualDisplayPrice, PricingConfig.fallbackProAnnualDisplayPrice)
    }

    #if DEBUG
    func testDebugTogglePremium() {
        let pm = PurchaseManager()
        XCTAssertFalse(pm.isPremium)
        pm.debugTogglePremium()
        XCTAssertTrue(pm.isPremium)
        pm.debugTogglePremium()
        XCTAssertFalse(pm.isPremium)
    }

    func testDebugSetPremiumPersistsToUserDefaults() {
        let pm = PurchaseManager()
        pm.debugSetPremium(true)
        XCTAssertTrue(pm.isPremium)
        // The App Group suite is the canonical store the widget reads.
        XCTAssertTrue(sharedDefaults.bool(forKey: premiumKey))
        // Mirror also written to `.standard` for legacy callers.
        XCTAssertTrue(UserDefaults.standard.bool(forKey: premiumKey))

        // A fresh manager picks up the persisted state (simulates app relaunch).
        let pm2 = PurchaseManager()
        XCTAssertTrue(pm2.isPremium)
    }
    #endif
}
