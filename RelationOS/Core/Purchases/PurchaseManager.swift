import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    /// "Has Pro entitlement right now" — true for paid subscribers AND for
    /// users still inside the 7-day install trial. Single source of truth
    /// for all UI gates.
    @Published private(set) var isPremium: Bool = false
    /// True only when isPremium is granted because of the install-trial
    /// (not a real subscription). Drives the "X days of Pro free remaining"
    /// banner and lets analytics tell trial-Pro from paid-Pro.
    @Published private(set) var isInIntroTrial: Bool = false
    /// Days remaining in the install trial (0 when expired or never started).
    @Published private(set) var introTrialDaysRemaining: Int = 0
    /// True after a real subscription has been verified. Independent of the
    /// install trial — used for "should we even show the paywall" decisions.
    @Published private(set) var hasActiveSubscription: Bool = false
    @Published private(set) var proMonthlyProduct: Product?
    @Published private(set) var proAnnualProduct: Product?
    @Published private(set) var isPurchasing: Bool = false
    @Published var lastError: String?
    /// Set on each purchase attempt so the PaywallView can emit a properly
    /// tagged analytics event distinguishing user-cancel / pending / errors.
    /// Cleared at the start of each new attempt.
    @Published private(set) var lastFailureReason: String?

    private var updatesTask: Task<Void, Never>?
    /// Legacy key — kept so existing installs that previously cached an
    /// `isPremium=true` bit still recognise their subscription before the
    /// first refreshEntitlements() call returns. New writes go through
    /// `sharedDefaults.set(..., forKey: subscriptionKey)` below.
    private let premiumKey = "relationos.isPremium"
    private let subscriptionKey = "relationos.hasActiveSubscription"

    private let introTrial: IntroTrialClock

    /// App Group UserDefaults — same suite the widget extension reads from
    /// to decide between rendering the Daily Reconnect list and the
    /// "Upgrade to Pro" placeholder. See `ContactsStore.appGroupIdentifier`.
    private let sharedDefaults: UserDefaults = ContactsStore.appGroupDefaults()

    init(introTrial: IntroTrialClock = IntroTrialClock()) {
        self.introTrial = introTrial
        // Stamp install on first ever launch. Idempotent on every subsequent
        // launch — the existing stamp is preserved.
        introTrial.recordInstallIfNeeded()

        // Restore the cached subscription bit (subKey is the new authoritative
        // store; premiumKey is read as a legacy fallback for pre-trial-rewrite
        // installs that wrote to it).
        var subscribed = sharedDefaults.bool(forKey: subscriptionKey)
        if !subscribed && sharedDefaults.bool(forKey: premiumKey) {
            subscribed = true
        }

        #if DEBUG
        if ProcessInfo.processInfo.environment["RELATIONOS_FORCE_PREMIUM"] == "1"
            || sharedDefaults.bool(forKey: "RELATIONOS_FORCE_PREMIUM") {
            subscribed = true
        }
        #endif

        self.hasActiveSubscription = subscribed
        self.isInIntroTrial = introTrial.isWithinTrial()
        self.introTrialDaysRemaining = introTrial.daysRemaining()
        let composite = subscribed || self.isInIntroTrial
        self.isPremium = composite
        // Sync the composite to the App Group on every launch so the
        // widget sees the right state immediately — even on the very
        // first launch where the install trial has just been stamped.
        sharedDefaults.set(composite, forKey: premiumKey)
        UserDefaults.standard.set(composite, forKey: premiumKey)
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
            PortfolioAnalytics.shared.trackPaywallFailure(productId: PricingConfig.proMonthlyProductID, reason: .productUnavailable)
            return
        }
        await purchase(product)
    }

    func purchaseAnnual() async {
        guard let product = proAnnualProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            PortfolioAnalytics.shared.trackPaywallFailure(productId: PricingConfig.proAnnualProductID, reason: .productUnavailable)
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
            setSubscribed(true)
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
            setSubscribed(true); return
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
        setSubscribed(entitled)
    }

    /// Re-read the install-trial clock and republish derived state. Call
    /// from a foreground notification so the banner ticks down without a
    /// relaunch when the user crosses midnight.
    func refreshTrialState() {
        let within = introTrial.isWithinTrial()
        let days = introTrial.daysRemaining()
        if within != isInIntroTrial { self.isInIntroTrial = within }
        if days != introTrialDaysRemaining { self.introTrialDaysRemaining = days }
        recomputeIsPremium()
    }

    private func recomputeIsPremium() {
        let next = hasActiveSubscription || isInIntroTrial
        if next != isPremium {
            let wasPremium = isPremium
            isPremium = next
            // Mirror to App Group for the widget. The widget reads only the
            // composite isPremium — it doesn't care which side granted it.
            sharedDefaults.set(next, forKey: premiumKey)
            UserDefaults.standard.set(next, forKey: premiumKey)
            WidgetReloader.reloadAllIfAvailable()
            if next != wasPremium {
                Task { await DailyReconnectNotification.sync(isPremium: next) }
            }
        }
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
            setSubscribed(true)
        } else if transaction.revocationDate != nil {
            await refreshEntitlements()
        }
        await transaction.finish()
    }

    /// Update the subscription bit (paid Pro). Composite `isPremium` is
    /// recomputed from this + the install-trial state via
    /// `recomputeIsPremium()`.
    ///
    /// When a paid purchase lands (`value == true`) we also consume the
    /// install-trial so the user can't double-dip: install-trial + paid
    /// sub stacking would let them ride the 7-day grant on top of a
    /// running subscription. Per policy (2026-05-18) paid users go
    /// straight to paid Pro.
    private func setSubscribed(_ value: Bool) {
        if value != hasActiveSubscription {
            self.hasActiveSubscription = value
            sharedDefaults.set(value, forKey: subscriptionKey)
        }
        if value && isInIntroTrial {
            introTrial.consume()
            self.isInIntroTrial = false
            self.introTrialDaysRemaining = 0
        }
        recomputeIsPremium()
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
    func debugTogglePremium() { setSubscribed(!hasActiveSubscription) }
    func debugSetPremium(_ value: Bool) { setSubscribed(value) }
    /// Test hooks for the install trial.
    func debugRewindTrial(daysIn: Int) {
        introTrial.debugRewind(daysIn: daysIn)
        refreshTrialState()
    }
    func debugForceTrialExpired() {
        introTrial.debugForceExpired()
        refreshTrialState()
    }
    func debugResetTrial() {
        introTrial.debugReset()
        introTrial.recordInstallIfNeeded()
        refreshTrialState()
    }
    #endif
}
