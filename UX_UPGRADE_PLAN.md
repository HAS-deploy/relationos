# RelationOS — UX Upgrade Plan (Top 10)

Date: 2026-04-29. Audit: `UX_AUDIT.md`. Plan only — no code changes this pass.

Impact: HIGH = day-1/day-2 retention. MED = noticed by attentive users. LOW = polish.
Effort: S ≤ 1h, M ≤ ½ day, L > ½ day.
Review: Y = touches metadata/permissions/paywall (Stage 4A re-check needed). N = pure UX.

| # | Gap | Impact | Effort | Review | Files |
|---|---|---|---|---|---|
| 1 | **Daily Reconnect daily notification not scheduled.** Paywall benefit "5 people every morning" (`Core/Pricing/PricingConfig.swift:21`) only renders in-app — `ReminderManager.scheduleDailyReminder` (`Core/Reminders/ReminderManager.swift:57-76`) has zero callers. | HIGH | M | Y | `Core/Reminders/ReminderManager.swift`, `Features/Settings/SettingsView.swift` (toggle+time), `Core/Purchases/PurchaseManager.swift` (schedule on premium grant) |
| 2 | **No onboarding.** First launch drops into empty Contacts tab; user never learns about Reconnect, widget, or on-device privacy. (`Features/Contacts/ContactsListView.swift:56-74`) | HIGH | M | N | new `Features/Onboarding/OnboardingView.swift`, gate from `App/RootView.swift:24`, `hasSeenOnboarding` in `SettingsStore` |
| 3 | **Notification permission asked at wrong moment, denied state has no recovery.** First reminder add silently fires `requestAuthorization` (`Features/ContactDetail/ContactDetailView.swift:158-161`); deny → reminders save but never fire and UI never tells user. | HIGH | S | Y | `Features/ContactDetail/ContactDetailView.swift`, add inline `NotificationsBanner` |
| 4 | **No haptic / success feedback on primary actions.** `Support/View+Haptics.swift:7-22` helpers wired only into `Settings → Delete all data` (`SettingsView.swift:39`). | HIGH | S | N | `ContactsListView.swift:104-119`, `ContactDetailView.swift:88-91, 143-172`, `PaywallView.swift:188-197` |
| 5 | **No search/filter on contacts.** Free cap is 100; scrolling is the only retrieval path. (`Features/Contacts/ContactsListView.swift:22-29`) | HIGH | S | N | `Features/Contacts/ContactsListView.swift` — `.searchable` over name/notes/tags |
| 6 | **Accessibility labels completely missing** — `grep accessibilityLabel` returns 0 hits. Icon-only `+` (`ContactsListView.swift:40-49`), avatars (`ContactRow.swift:8-15`), lock overlay (`DailyReconnectView.swift:74-99`), tag-delete xmark (`ContactDetailView.swift:57-61`). | MED | M | N | `ContactsListView.swift`, `ContactRow.swift`, `ContactDetailView.swift`, `DailyReconnectView.swift`, `SettingsView.swift` |
| 7 | **"Log interaction now" produces no visible confirmation** for ~1s until the relative-date label refreshes. (`Features/ContactDetail/ContactDetailView.swift:88-91`) | MED | S | N | `Features/ContactDetail/ContactDetailView.swift` — animate label, haptic, checkmark flash |
| 8 | **Past-date reminder silently drops.** `DatePicker` (`ContactDetailView.swift:123`) accepts any date; `UNCalendarNotificationTrigger` ignores past times with no warning. | MED | S | N | `Features/ContactDetail/ContactDetailView.swift` — `in: Date()...` bound + validation |
| 9 | **Free-tier Reconnect placeholder labels itself "Sample"** (`Features/Reconnect/DailyReconnectView.swift:62-71`) — reads as fake content, undermines pitch. | LOW | S | Y | `Features/Reconnect/DailyReconnectView.swift:58-72` — lead with upgrade card, drop the "Sample" word |
| 10 | **No undo / confirmation on contact swipe-delete.** Swipe (`ContactsListView.swift:28`) wipes contact + reminders permanently. | LOW | M | N | `Features/Contacts/ContactsListView.swift` — confirm sheet or 5s undo banner |

## Honorable mentions
- "Not yet touched" microcopy (`ContactRow.swift:29`).
- Duplicate contact names allowed silently (`ContactsListView.swift:104-119`).
- No widget add-to-home tip after 3+ contacts.
- No character limit on text fields.

## Risk notes if implementing
- Items 1, 3, 9 touch advertised functionality / permissions — **must** re-clear Stage 4A before resubmission.
- Item 1: pair with Settings toggle (4.5.4 expectation, even though Pro is opt-in).
- Items 2, 4, 5, 6, 7, 8, 10 — pure local UI, no review impact.

---

## Verdict — would a typical user open RelationOS twice?

**MAYBE.**

Rationale: architecture is sound — clean SwiftUI, real on-device persistence, working paywall, working widget, system-aware dark mode, honest microcopy, real privacy posture. A user who already understands what a personal CRM is for, manually adds 5–10 contacts, and sets reminders, will get value.

But the headline retention feature — "Five people. Every morning." — is **not wired as a notification**, only as an in-app view. A user who closes the app after onboarding has no system-level reason to come back tomorrow. Combined with zero onboarding (the widget and Reconnect tab are never introduced), day-2 retention leans entirely on the user's own willpower. That is the gap between MAYBE and YES.

Three changes flip this to YES with about half a day of work: (1) actually schedule the daily reconnect notification on Pro grant + Settings toggle/time picker, (2) ship a 3-screen onboarding introducing Reconnect and the widget, (3) add `.searchable` to the contact list. Items 4 and 6 (haptics + accessibility) are the difference between MAYBE and "feels native."

Without those three, the app is technically correct but emotionally inert — a user opens it, types in 8 contacts, doesn't get reminded the next morning, and forgets it exists by Friday.
