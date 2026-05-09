import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var proMonthlyProduct: Product?
    @Published private(set) var proAnnualProduct: Product?
    @Published private(set) var isPurchasing: Bool = false
    @Published var lastError: String?
    /// Set on each purchase attempt so the PaywallView can emit a properly
    /// tagged analytics event distinguishing user-cancel / pending / errors.
    /// Cleared at the start of each new attempt.
    @Published private(set) var lastFailureReason: String?

    private var updatesTask: Task<Void, Never>?
    private let premiumKey = "relationos.isPremium"

    /// App Group UserDefaults — same suite the widget extension reads from
    /// to decide between rendering the Daily Reconnect list and the
    /// "Upgrade to Pro" placeholder. See `ContactsStore.appGroupIdentifier`.
    private let sharedDefaults: UserDefaults = ContactsStore.appGroupDefaults()

    init() {
        var initial = sharedDefaults.bool(forKey: premiumKey)
        #if DEBUG
        if ProcessInfo.processInfo.environment["RELATIONOS_FORCE_PREMIUM"] == "1"
            || sharedDefaults.bool(forKey: "RELATIONOS_FORCE_PREMIUM") {
            initial = true
        }
        #endif
        self.isPremium = initial
    }

    deinit { updatesTask?.cancel() }

    func start() async {
        await loadProducts()
        await refreshEntitlements()
        observeTransactionUpdates()
    }

    var proMonthlyDisplayPrice: String {
        proMonthlyProduct?.displayPrice ?? PricingConfig.fallbackProMonthlyDisplayPrice
    }

    var proAnnualDisplayPrice: String {
        proAnnualProduct?.displayPrice ?? PricingConfig.fallbackProAnnualDisplayPrice
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: PricingConfig.allProductIDs)
            self.proMonthlyProduct = products.first { $0.id == PricingConfig.proMonthlyProductID }
            self.proAnnualProduct  = products.first { $0.id == PricingConfig.proAnnualProductID }
        } catch {
            self.lastError = "Couldn't load the store. Check your connection and try again."
        }
    }

    func purchaseMonthly() async {
        guard let product = proMonthlyProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        await purchase(product)
    }

    func purchaseAnnual() async {
        guard let product = proAnnualProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        await purchase(product)
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        lastFailureReason = nil
        do {
            let result = try await product.purchase()
            try await handle(result: result, product: product)
        } catch {
            self.lastError = error.localizedDescription
            self.lastFailureReason = error.localizedDescription
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, error: error)
        }
    }

    private func handle(result: Product.PurchaseResult, product: Product) async throws {
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            setPremium(true)
            await transaction.finish()
        case .userCancelled:
            lastFailureReason = "user_cancelled"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .userCanceled)
        case .pending:
            self.lastError = "Purchase is pending approval."
            lastFailureReason = "pending_approval"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .pending)
        @unknown default:
            lastFailureReason = "storekit_unknown_case"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .unknown)
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremium { self.lastError = "No previous purchases found on this Apple ID." }
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        #if DEBUG
        // Read from the App Group suite (same source `init()` reads from)
        // so the debug-toggle path is consistent across launch and refresh.
        if ProcessInfo.processInfo.environment["RELATIONOS_FORCE_PREMIUM"] == "1"
            || sharedDefaults.bool(forKey: "RELATIONOS_FORCE_PREMIUM") {
            setPremium(true); return
        }
        #endif
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               PricingConfig.allProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        setPremium(entitled)
    }

    private func observeTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.handleVerifiedUpdate(transaction)
                }
            }
        }
    }

    private func handleVerifiedUpdate(_ transaction: Transaction) async {
        if PricingConfig.allProductIDs.contains(transaction.productID),
           transaction.revocationDate == nil {
            setPremium(true)
        } else if transaction.revocationDate != nil {
            await refreshEntitlements()
        }
        await transaction.finish()
    }

    private func setPremium(_ value: Bool) {
        let wasPremium = self.isPremium
        self.isPremium = value
        sharedDefaults.set(value, forKey: premiumKey)
        // Mirror to standard for any legacy reader; harmless duplicate.
        UserDefaults.standard.set(value, forKey: premiumKey)
        WidgetReloader.reloadAllIfAvailable()
        if value != wasPremium {
            Task { await DailyReconnectNotification.sync(isPremium: value) }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw PurchaseError.failedVerification
        case .verified(let value): return value
        }
    }

    enum PurchaseError: LocalizedError {
        case failedVerification
        var errorDescription: String? { "Purchase could not be verified." }
    }

    #if DEBUG
    func debugTogglePremium() { setPremium(!isPremium) }
    func debugSetPremium(_ value: Bool) { setPremium(value) }
    #endif
}
