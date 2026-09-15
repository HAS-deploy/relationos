import Foundation

/// 14-day-from-install Pro grant.
///
/// As of 2026-05-14 RelationOS switched off Apple's introductory-offer
/// model (which gates the 14 days behind a subscription tap) and replaced
/// it with an install-time grant: every fresh install gets full Pro for
/// 14 days, no card, no commitment, no paywall. After day 14 the user
/// falls back to the free tier and the paywall starts gating Pro-only
/// surfaces normally.
///
/// Mechanics:
///   * On first launch we stamp `installAt` into App Group UserDefaults.
///     Subsequent launches read the existing stamp — never overwrite it.
///   * `isWithinTrial(now:)` does the date math against `length`.
///   * `daysRemaining(now:)` is the number the paywall + settings show.
///   * `consume()` is called by PurchaseManager when a paid purchase
///     lands, so the install-trial doesn't double-up on top of a paid
///     subscription.
///
/// Restoring an old install: a clean reinstall on the same Apple ID will
/// re-stamp from "now" — that's intentional. The trial is install-scoped,
/// not Apple-ID-scoped. If/when we want device-side anti-abuse we can
/// switch to StoreKit's `Transaction.deviceVerification` UUID, but for
/// v1.1 the simpler local stamp is enough.
struct IntroTrialClock {
    static let length: TimeInterval = TimeInterval(PricingConfig.installTrialDays) * 24 * 60 * 60
    private static let installAtKey = "relationos.intro_trial.install_at"
    private static let consumedKey  = "relationos.intro_trial.consumed"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = ContactsStore.appGroupDefaults()) {
        self.defaults = defaults
    }

    /// Stamp installAt the first time we ever see this device. No-op on
    /// every subsequent launch. Returns the resolved installAt.
    @discardableResult
    func recordInstallIfNeeded(now: Date = Date()) -> Date {
        if let existing = defaults.object(forKey: Self.installAtKey) as? Date {
            return existing
        }
        defaults.set(now, forKey: Self.installAtKey)
        return now
    }

    var installAt: Date? {
        defaults.object(forKey: Self.installAtKey) as? Date
    }

    /// True iff the device is inside its 14-day install window AND the
    /// trial hasn't been consumed (either by a paid purchase landing or
    /// by the debug toggle).
    func isWithinTrial(now: Date = Date()) -> Bool {
        guard !defaults.bool(forKey: Self.consumedKey),
              let installAt = installAt else { return false }
        return now.timeIntervalSince(installAt) < Self.length
    }

    /// Rounded-up days remaining (so a fresh install shows "14 days left",
    /// not "6 days, 23 hours"). Zero when the trial is over.
    func daysRemaining(now: Date = Date()) -> Int {
        guard isWithinTrial(now: now), let installAt = installAt else { return 0 }
        let elapsed = now.timeIntervalSince(installAt)
        let remaining = Self.length - elapsed
        return max(0, Int(ceil(remaining / 86400)))
    }

    /// Mark the install trial as consumed. Called by `PurchaseManager`
    /// when a paid purchase lands so the trial doesn't double-up on top
    /// of a paid subscription. Idempotent.
    func consume() {
        defaults.set(true, forKey: Self.consumedKey)
    }

    #if DEBUG
    /// Skip-ahead for QA / screenshots. Sets installAt back so the trial
    /// reads as if `daysIn` days have already passed.
    func debugRewind(daysIn: Int) {
        let synthetic = Date().addingTimeInterval(-Double(daysIn) * 86400)
        defaults.set(synthetic, forKey: Self.installAtKey)
        defaults.set(false, forKey: Self.consumedKey)
    }

    func debugForceExpired() {
        defaults.set(true, forKey: Self.consumedKey)
    }

    func debugReset() {
        defaults.removeObject(forKey: Self.installAtKey)
        defaults.set(false, forKey: Self.consumedKey)
    }
    #endif
}
