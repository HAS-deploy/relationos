//  PortfolioAnalytics.swift
//  App Factory — shared Swift drop-in (canonical 2026-04-26 schema lock).
//
//  PostHog is linked. Privacy-strict configuration:
//    - captureApplicationLifecycleEvents = false
//    - captureScreenViews = false
//    - sessionReplay = false
//    - personProfiles = .never
//
//  Anonymous events tied to a random per-install identifier. No PII. No
//  App Tracking Transparency prompt. Disclosed in the privacy policy.

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif
import CryptoKit
#if canImport(StoreKit)
import StoreKit
#endif

#if canImport(PostHog)
import PostHog
#endif

// MARK: - Top-level

final class PortfolioAnalytics: @unchecked Sendable {
    static let shared = PortfolioAnalytics()

    // Configuration
    private var started = false
    private var appName: String = "unknown"

    // Mutable runtime traits — kept in memory so we can attach them to every
    // event without re-reading per call.
    private var isPremium: Bool = false
    private var userSegment: UserSegment = .anonymous
    private var locale: String = Locale.current.identifier
    private var firstLaunchAt: Date = Date()

    // Opt-out (persisted)
    private static let kOptedOut = "portfolio.analytics.opted_out"
    private static let kFirstLaunch = "portfolio.analytics.first_launch_at"
    private static let kIdentified = "portfolio.analytics.identified"

    private init() {}

    // MARK: Lifecycle

    func start(appName: String) {
        guard !started else { return }
        self.appName = appName

        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: Self.kFirstLaunch) as? Date {
            firstLaunchAt = stored
        } else {
            firstLaunchAt = Date()
            defaults.set(firstLaunchAt, forKey: Self.kFirstLaunch)
        }

        guard !isOptedOut else {
            started = true
            return
        }

        #if canImport(PostHog)
        let key = (Bundle.main.object(forInfoDictionaryKey: "PostHogKey") as? String) ?? ""
        let host = (Bundle.main.object(forInfoDictionaryKey: "PostHogHost") as? String)
            ?? "https://us.i.posthog.com"
        guard !key.isEmpty else {
            started = true
            return
        }
        let config = PostHogConfig(apiKey: key, host: host)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.sessionReplay = false
        config.personProfiles = .never
        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.register(["app": appName])
        #endif

        started = true
    }

    // MARK: Identity

    func identify(userId: String, traits: [String: Any] = [:]) {
        guard started, !isOptedOut else { return }
        #if canImport(PostHog)
        PostHogSDK.shared.identify(userId, userProperties: traits)
        #endif
        UserDefaults.standard.set(true, forKey: Self.kIdentified)
    }

    func reset() {
        guard started else { return }
        #if canImport(PostHog)
        PostHogSDK.shared.reset()
        #endif
        UserDefaults.standard.set(false, forKey: Self.kIdentified)
    }

    // MARK: Entitlement

    enum UserSegment: String {
        case anonymous, free, trial, premium, lifetime
    }

    func setEntitlement(isPremium: Bool, segment: UserSegment) {
        self.isPremium = isPremium
        self.userSegment = segment
        guard started, !isOptedOut else { return }
        #if canImport(PostHog)
        PostHogSDK.shared.register(["user_segment": segment.rawValue,
                                    "is_premium": isPremium])
        #endif
    }

    // MARK: Opt-out

    var isOptedOut: Bool {
        UserDefaults.standard.bool(forKey: Self.kOptedOut)
    }

    func optOut() {
        UserDefaults.standard.set(true, forKey: Self.kOptedOut)
        #if canImport(PostHog)
        if started { PostHogSDK.shared.optOut() }
        #endif
    }

    func optIn() {
        UserDefaults.standard.set(false, forKey: Self.kOptedOut)
        #if canImport(PostHog)
        if started { PostHogSDK.shared.optIn() }
        #endif
    }

    // MARK: Track

    func track(_ event: String, _ props: [String: Any] = [:]) {
        guard started, !isOptedOut else { return }
        #if canImport(PostHog)
        var enriched = props
        enriched["app"] = appName
        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            enriched["app_version"] = v
        }
        if let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            enriched["build"] = b
        }
        enriched["locale"] = locale
        enriched["user_segment"] = userSegment.rawValue
        enriched["is_premium"] = isPremium
        enriched["days_since_install"] = max(0, Int(Date().timeIntervalSince(firstLaunchAt) / 86400))
        PostHogSDK.shared.capture(event, properties: enriched)
        #endif
    }

    // MARK: - Helpers (no-op without PostHog, kept for call-site uniformity)

    func trackPaywallFailure(productId: String,
                             reason: PurchaseFailureReason,
                             errorCode: String? = nil,
                             attemptNumber: Int? = nil) {
        var p: [String: Any] = ["product_id": productId, "reason": reason.rawValue]
        if let c = errorCode { p["error_code"] = c }
        if let n = attemptNumber { p["attempt_number"] = n }
        track(PortfolioEvent.paywallPurchaseFailed, p)
    }

    func trackPaywallFailure(productId: String, error: Error, attemptNumber: Int? = nil) {
        let reason = PurchaseFailureReason(error: error)
        let code = String(describing: error).prefix(200)
        trackPaywallFailure(productId: productId,
                            reason: reason,
                            errorCode: String(code),
                            attemptNumber: attemptNumber)
    }
}

// MARK: - Enums

enum PaywallTriggerSource: String {
    case settings, onboarding, featureGate = "feature_gate", limitHit = "limit_hit"
    case deepLink = "deep_link", push, restoreFailed = "restore_failed"
}

enum PurchaseFailureReason: String {
    case userCanceled = "user_canceled"
    case pending
    case noPaymentMethod = "no_payment_method"
    case notInStorefront = "not_in_storefront"
    case networkError = "network_error"
    case verificationFailed = "verification_failed"
    case unverifiedReceipt = "unverified_receipt"
    case unknown

    init(error: Error) {
        #if canImport(StoreKit)
        if let skErr = error as? StoreKitError {
            switch skErr {
            case .userCancelled: self = .userCanceled; return
            case .networkError: self = .networkError; return
            case .notAvailableInStorefront: self = .notInStorefront; return
            case .notEntitled: self = .verificationFailed; return
            case .systemError: self = .unknown; return
            case .unknown: self = .unknown; return
            @unknown default: self = .unknown; return
            }
        }
        if let purchaseErr = error as? Product.PurchaseError {
            switch purchaseErr {
            case .productUnavailable: self = .notInStorefront; return
            case .invalidQuantity, .invalidOfferIdentifier, .invalidOfferPrice, .invalidOfferSignature:
                self = .verificationFailed; return
            case .missingOfferParameters, .ineligibleForOffer:
                self = .verificationFailed; return
            @unknown default: self = .unknown; return
            }
        }
        #endif
        if let urlErr = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(urlErr.code) {
            self = .networkError; return
        }
        self = .unknown
    }
}

enum PortfolioEvent {
    static let install                 = "install"
    static let appForegrounded         = "app.foregrounded"
    static let paywallViewed           = "paywall.viewed"
    static let paywallPurchaseClick    = "paywall.purchase_clicked"
    static let paywallPurchaseSuccess  = "paywall.purchase_success"
    static let paywallPurchaseFailed   = "paywall.purchase_failed"
    static let paywallRestoreClick     = "paywall.restore_clicked"
    static let restoreCompleted        = "restore.completed"
}
