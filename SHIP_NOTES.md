# Ship Notes — RelationOS v1.0.1 (paying-user audit fixes)

**Source audit:** `/Users/tony/Documents/portfolio-audit/12-relationos.md` (2 HARD, 4 SIGNIFICANT, 4 POLISH)
**Branch:** master (v1.0 WAITING_FOR_REVIEW as of 2026-05-09)
**Scope:** v1.0.1 surgical fixes — no version bump in this commit; no StoreKit changes; persistence schemas untouched.

## Summary

- 2 HARDs fixed
- 2 SIGNIFICANTs fixed (denied-state recovery + notification pre-prompt)
- 4 POLISH fixed (past-date DatePicker, haptics, accessibility labels, denied-state inline)
- 2 DEFERRED (SwiftData persistence migration / 1000-contact warning; first-launch onboarding carousel) — both >30 min, structural

## Fixes

### HARD

- **H1 — Analytics opt-out toggle.** Added "Anonymous Usage Analytics" toggle in
  `SettingsView.privacySection` wired via `@AppStorage("portfolio.analytics.opted_out")`
  to `PortfolioAnalytics.shared.optIn() / optOut()` (Pattern A from FIX_GUIDELINES).
  Footer copy updated to describe what's collected and how to turn it off. The
  underlying SDK opt-out machinery was already in place at
  `PortfolioAnalytics.swift:131-143` — this only surfaces it.
  Files: `RelationOS/Features/Settings/SettingsView.swift`.

- **H2 — Cooling relationships duplicate bullet collapsed.** "Cooling
  relationships highlighted" was sold as a separate paid feature but is the same
  `lastInteractedAt`-sort heuristic that powers Daily Reconnect — there's no
  dedicated UI surface (no row badge, no filter, no separate tab). Per the
  owner's call, the cleanest path is to remove the duplicate bullet rather than
  ship a half-baked second UI. Updated `PricingConfig.paywallBenefits` to a
  single line: "Daily reconnect list — 5 people every morning, ordered by who's
  gone coldest". `SettingsView` premium-footer copy also rewritten to match.
  Files: `RelationOS/Core/Pricing/PricingConfig.swift`,
  `RelationOS/Features/Settings/SettingsView.swift`.

  **ASC metadata edit required:** App Store description still lists "cooling
  relationships highlighted" as a separate bullet — owner must remove that line
  and replace with the new bullet text above before re-submitting v1.0.1.

### SIGNIFICANT

- **S1 — Reminder denied-state recovery.** Added an inline orange banner inside
  `ContactDetailView.remindersSection` that surfaces when the user has at least
  one reminder AND `notificationAuthStatus == .denied`. Banner explains
  reminders won't alert and includes a `Link("Open Settings", destination:
  UIApplication.openSettingsURLString)` deep-link into iOS Settings → RelationOS.
  The add-reminder sheet footer also flips to an orange "Notifications are off"
  variant when denied. `notificationAuthStatus` is captured in `.task` on view
  appear and re-checked after permission-flow completion.
  Files: `RelationOS/Features/ContactDetail/ContactDetailView.swift`.

- **S2 — Notification pre-prompt.** Added a custom explainer sheet
  (`notificationPrePromptSheet`) that fires on the first "Add reminder" tap when
  `notificationAuthStatus == .notDetermined` AND
  `@AppStorage("relationos.reminders.preprompt_shown")` is false. Sheet explains
  what notifications are used for, that they're local-only, and that iOS asks
  once. After "Continue", `requestAuthorization()` runs and the add-reminder
  sheet opens. After "Not now", the add-reminder sheet still opens (we don't
  block them from saving locally) but the iOS prompt is deferred. Inline
  authorization-request was removed from `addReminder()` since the pre-prompt
  now owns that path. (Audit also flagged the equivalent issue in
  `DailyReconnectNotification.sync:25-33` — left as DEFERRED, see below.)
  Files: `RelationOS/Features/ContactDetail/ContactDetailView.swift`.

### POLISH

- **P1 — Past-date DatePicker.** Constrained reminder DatePicker to
  `in: Date()...` to stop the user from selecting a past trigger that
  `UNCalendarNotificationTrigger` would silently drop.
  File: `RelationOS/Features/ContactDetail/ContactDetailView.swift:274`.

- **P2 — Haptics on primary actions.** Added `.hapticSuccess(trigger:)` to:
  contact added (manual + import announce path) in `ContactsListView`,
  reminder added in `ContactDetailView`, "Mark touched now" in
  `ContactDetailView`. Uses the existing `View+Haptics.swift` helpers
  (iOS 17+ `.sensoryFeedback`, no-op older). Purchase-complete and
  restore-complete haptics deferred to keep the StoreKit code path
  untouched per FIX_GUIDELINES rule #2.
  Files: `RelationOS/Features/Contacts/ContactsListView.swift`,
  `RelationOS/Features/ContactDetail/ContactDetailView.swift`.

- **P3 — Accessibility labels.** Combined `ContactRow` initials avatar +
  name + last-touched into a single VoiceOver element with a synthesized
  label ("\<name\>, \<lastTouched\>"); marked the decorative initials
  avatar `.accessibilityHidden(true)`. Added `accessibilityLabel("Add or
  import contacts")` on the toolbar `+` button. Added
  `accessibilityHint(...)` on the Analytics toggle and the "Add reminder"
  button. Full a11y pass across all screens remains DEFERRED.
  Files: `RelationOS/Features/Contacts/ContactRow.swift`,
  `RelationOS/Features/Contacts/ContactsListView.swift`,
  `RelationOS/Features/Settings/SettingsView.swift`,
  `RelationOS/Features/ContactDetail/ContactDetailView.swift`.

- **P4 — Denied-state inline (covered under S1).** The inline banner is
  the polish surface called out at audit POLISH; same change addresses it.

## DEFERRED

- **SIG3 — Contacts list 1,000+ JSON-blob persistence cliff** (audit SIG #3).
  The fix is either persist-throttling or a SwiftData migration (already TODO'd
  at `ContactsStore.swift:4-8`). >30 min, touches the persistence layer +
  schema. Recommend tackling as a focused v1.1 task; in the meantime, the free
  cap is 100 and Pro users hitting 2,500-contact vCard imports are still rare.
  No code change in this commit.

- **POLISH — First-launch onboarding carousel** (audit POLISH #3). 2-3 screen
  intro covering Daily Reconnect, 14-day install trial, on-device privacy.
  Structural new feature, >30 min, not a fix. Recommend for v1.1.

- **DailyReconnectNotification.sync silent-authorization request** (audit
  SIG #2 second half). The notification path at
  `DailyReconnectNotification.swift:25-33` requests authorization the moment
  the user becomes premium — same wrong-moment issue, but routing a
  pre-prompt through the entitlement-flip flow (which runs from
  `PurchaseManager.recomputeIsPremium`) needs a UI gate that lives above the
  app's root and persists across launches. Out of scope for a 30-min surgical
  fix without touching the StoreKit-adjacent state machine. Deferring; the
  in-app ContactDetail pre-prompt added in S2 covers the more common path
  (user adds a reminder before subscribing).

## ASC metadata edits required (owner action)

1. **App Store description:** Remove "Cooling relationships highlighted" as a
   distinct bullet. Replace the Daily Reconnect line with: "Daily reconnect
   list — 5 people every morning, ordered by who's gone coldest". This mirrors
   the new in-app paywall bullet exactly.

## Risk notes

- The pre-prompt sheet is a new UI surface inside an existing flow. If a user
  has already been through the system prompt once (status `.authorized` or
  `.denied`), the pre-prompt is bypassed entirely — only fires when
  status is `.notDetermined` AND the explainer has not been shown before. Low
  blast radius.
- `@AppStorage("relationos.reminders.preprompt_shown")` and
  `@AppStorage("portfolio.analytics.opted_out")` keys are new persisted
  state but use standard `UserDefaults` — no schema migration, no risk to
  existing contacts/notes/reminders.
- `PaywallDisclosureTests` was checked: it does not assert on the cooling
  bullet text, only the four 3.1.2(a) sentences and structural strings. No
  test regression expected.
- DO NOT push, bump version, or submit. Owner builds + ships in serial
  phase after all portfolio agents commit.
