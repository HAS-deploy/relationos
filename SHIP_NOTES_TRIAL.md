# SHIP_NOTES_TRIAL — install-trial standardization (2026-05-18)

Standardized RelationOS's install-trial to match the portfolio-wide pattern
defined in `/Users/tony/Documents/portfolio-audit/INSTALL_TRIAL_SPEC.md`.

RelationOS is the canonical reference implementation for the other 10
affected apps, so these changes set the template: 7-day install-trial,
highest-tier entitlement during the window, consume-on-paid hook so the
trial can't double-up with a paid subscription.

## Changes

### Duration: 14 days → 7 days

- `RelationOS/Core/Purchases/IntroTrialClock.swift`
  - `Self.length` constant: `14 * 24 * 60 * 60` → `7 * 24 * 60 * 60`.
  - Docstring header rewritten (14-day-from-install → 7-day-from-install).
  - Comment on `isWithinTrial` and `daysRemaining` updated to 7 days.

### Cancel-on-paid wiring (new)

- `IntroTrialClock.consume()` — new public method, idempotently flips the
  `consumedKey` defaults flag to true so `isWithinTrial` returns false.
- `PurchaseManager.setSubscribed(_:)` — when `value == true` AND
  `isInIntroTrial` is currently true, calls `introTrial.consume()` and
  clears the published `isInIntroTrial` / `introTrialDaysRemaining`
  before recomputing `isPremium`. This is the cancel-on-paid hook the
  spec requires: paid users go straight to paid Pro, no double-trial.

  Note: `setSubscribed(false)` (revocation / refund) does NOT un-consume
  the trial. That's intentional — once a user has paid, the install-trial
  is spent; if they cancel they fall to the free tier, not back into a
  fresh trial. Matches the policy ("No double-trial").

### Paywall / settings copy

- `RelationOS/Features/Settings/SettingsView.swift` (line 132): banner
  copy "Your 14-day Pro trial started on first launch…" → "Your 7-day
  Pro trial started on first launch…".
- `RelationOS/Features/Settings/SettingsView.swift` (line 243): debug
  button label "Reset trial (re-grant 14 days)" → "Reset trial (re-grant
  7 days)".
- `RelationOS/Features/Paywall/PaywallView.swift` (line 148): comment
  on `planMicrocopy` mentions "14-day free chunk" → "7-day free chunk".
  (The user-facing string itself is already dynamic — `"Starts after
  your \(n)-day Pro trial ends"` — so no copy change needed there.)
- `RelationOS/Core/Purchases/PurchaseManager.swift` (`isPremium`
  docstring): "still inside the 14-day install trial" → "still inside
  the 7-day install trial".

### Test fixtures

- `RelationOSTests/PurchaseManagerTests.swift`
  - Renamed `testFreshInstallGrantsTrialAndProForFourteenDays` →
    `testFreshInstallGrantsTrialAndProForSevenDays`, asserts
    `introTrialDaysRemaining == 7`.
  - `testDebugRewindMovesUserCloserToTrialExpiry`: starts at 7, rewinds
    by 6 days (was 14 / rewind 13) → 1 day remaining. Same shape, new
    duration.
- `RelationOSTests/PricingConfigTests.swift`: comment "Pro free for 14
  days from install" → "Pro free for 7 days from install".
- `RelationOSTests/PaywallDisclosureTests.swift`: comment "The 14-day
  trial" → "The 7-day trial".

## Verifications

1. **`consumed` flag set on paid purchase**: confirmed.
   `PurchaseManager.handle(result:product:)` calls `setSubscribed(true)`
   in the `.success` branch (line 136). `setSubscribed` now calls
   `introTrial.consume()` when transitioning to subscribed with an
   active trial. Also covers the `Transaction.updates` listener path
   (`handleVerifiedUpdate`) which also flows through `setSubscribed`.
2. **Entitlement gate returns highest tier during trial**: confirmed.
   The app has a single composite `isPremium` flag (no partial-unlock
   intermediate tier in RelationOS — Pro is the only paid tier). During
   trial, `isInIntroTrial == true` → `recomputeIsPremium()` sets
   `isPremium = true`. All UI gates read from `isPremium`. The widget
   reads the same composite via the App Group `premiumKey` defaults
   mirror.
3. **No StoreKit plumbing touched**: `Transaction.updates` listener,
   `Transaction.currentEntitlements` scan, `AppStore.sync()` restore,
   product loading — all untouched. Surgical edit only.
4. **No product ID renames**: `PricingConfig.allProductIDs` untouched.
5. **No SwiftData @Model schema changes**: not touched.

## Out of scope (per spec)

- ASC subscription-level free trial — already stripped earlier;
  IntroTrialClock is now the only trial source.
- xcodebuild / version bump / push — not run.

## Follow-ups (for the other 10 apps)

Use this RelationOS shape as the template. Specifically:

- The new `consume()` method on `IntroTrialClock` is the cleanest spot
  for the cancel-on-paid hook — single line, idempotent. Each per-app
  `PurchaseManager` (or equivalent EntitlementStore) should call it
  inside its subscription-success handler when transitioning into the
  paid state from an active install-trial.
- Duration constant lives on the clock struct as `length`. Standard
  value: `7 * 24 * 60 * 60`.
- Highest-tier verification per app needs to confirm the entitlement
  gate returns the top tier (Pro / Premium / Plus depending on the
  app's naming) — not a partial unlock — when `isWithinTrial` is true.
