# RelationOS — Stage 3.5 UX Polish Audit

Date: 2026-04-29 · post-remediation, archive uploaded today, 21/21 tests pass.
Question: **would a real user open this twice?** (Different from "will Apple reject?".)

## App summary

Private on-device personal CRM. 3 tabs — Contacts / Reconnect / Settings (`RelationOS/App/RootView.swift:25-43`). Free tier 100 contacts; Pro $11.99/mo or $89.99/yr, 14-day trial, default annual (`Core/Pricing/PricingConfig.swift:10-26`). UserDefaults+JSON in App Group `group.com.relationos.app`; widget reads same blob (`Core/Persistence/ContactsStore.swift:22-40`). Notifications-only permission, requested lazily (`Features/ContactDetail/ContactDetailView.swift:158-161`).

## Findings

### Empty states
- Contacts list: friendly, mentions free cap (`Features/Contacts/ContactsListView.swift:56-74`). OK.
- Daily Reconnect (Pro, no candidates): explains heuristic (`Features/Reconnect/DailyReconnectView.swift:39-47`). OK.
- Daily Reconnect (free): "Sample · upgrade to see your list" reads as fake content (`DailyReconnectView.swift:62-71`).
- ContactDetail tags + reminders: bare `Text("No tags yet")` / `Text("No reminders yet")` in `.caption` — flat, no CTA. (`Features/ContactDetail/ContactDetailView.swift:51, 99`)

### Loading states
- Single `ProgressView` — paywall purchase spinner (`Features/Paywall/PaywallView.swift:202`). `loadProducts()` runs at launch silently (`Core/Purchases/PurchaseManager.swift:51-59`); first paywall open on slow network shows fallback price quietly. Acceptable for v1.

### Error states / recovery
- Paywall surfaces `purchases.lastError` in red (`PaywallView.swift:53`); StoreKit copy is friendly (`PurchaseManager.swift:57`). OK.
- Reminder scheduling uses `try?` and silently swallows failures (`ContactDetailView.swift:162-167`). If user **denies** notifications, reminder still saves but no system notification fires and the UI never tells them. Hard gap.
- Only `notDetermined` triggers a request (`ContactDetailView.swift:158-161`); `denied` has no recovery surface.

### Success feedback / haptics
- Helpers exist (`Support/View+Haptics.swift:7-22`). Only call site: `Settings → Delete all data` (`SettingsView.swift:39`).
- No haptic on contact added, deleted, tag added, "Log interaction now", reminder added, purchase completed, restore success. Every primary action is silent. No toast / inline confirmation either — sheets just dismiss.

### Accessibility
- `grep accessibilityLabel|accessibilityHint|accessibility(` across both targets returns **zero hits**. Decorative SF Symbols (`ContactsListView.swift:58`, `DailyReconnectView.swift:78`, `SettingsView.swift:62`) carry no labels or `.accessibilityHidden(true)`.
- `ContactRow` initials avatar (`Features/Contacts/ContactRow.swift:8-15`) has no combined-element label; VoiceOver reads initials letter-by-letter.
- Custom paywall-trigger button stack (`DailyReconnectView.swift:74-99`) has no hint that it opens a paywall.
- Dynamic Type: mostly system fonts. `font(.system(size: 44))` empty-state icon (`ContactsListView.swift:59`) is fixed. Minor.

### Dark mode
- AccentColor has light + dark variants (`Resources/Assets.xcassets/AccentColor.colorset/Contents.json:14-32`). Cards use `secondarySystemBackground` (`App/Theme.swift:6`). User can force light/dark/system (`SettingsView.swift:81-88`, `Core/Persistence/SettingsStore.swift:25-43`). All good.

### Microcopy
- Paywall benefits + disclosures tight and accurate (`Core/Pricing/PricingConfig.swift:18-23`, `Features/Paywall/PaywallView.swift:13-29`).
- "Not yet touched" (`ContactRow.swift:29`) reads awkward; "No interactions yet" cleaner.
- Settings honestly says "Cloud sync is on the v1.1 roadmap." (`SettingsView.swift:112`). Good.

### Animation
- `grep withAnimation|animation(|transition` returns **zero hits**. System defaults only. "Log interaction now" (`ContactDetailView.swift:88-91`) updates state instantly with no visual confirmation — feels like nothing happened.

### Onboarding
- **None.** First launch lands on empty Contacts tab with generic "Tap + to add" (`ContactsListView.swift:62`). Daily Reconnect, the widget, and the on-device privacy story — the actual differentiators — are never introduced.
- No notification pre-prompt: request fires the moment the user adds their first reminder (`ContactDetailView.swift:159-161`), with no rationale. iOS denies-once is permanent; this is the wrong moment.

### Retention loops
- Daily reconnect notification scaffolding exists (`Core/Reminders/ReminderManager.scheduleDailyReminder` `ReminderManager.swift:57-76`) but **nothing schedules it** — zero call-sites. The headline feature ("Five people. Every morning." `DailyReconnectView.swift:28`, paywall benefit `PricingConfig.swift:21`) is **not wired as a recurring notification** — only renders in-app when the user opens the tab. Critical.
- Widget exists (`RelationOSWidgets/DailyReconnectWidget.swift:12-27`), refreshes 6am (`DailyReconnectStore.swift:63-72`). But user has to know to add it — no in-app prompt.
- No badge count for due reminders.

### Edge cases
- Duplicate contact names allowed silently (`ContactsListView.swift:104-119`).
- No character limit on Notes / Tags / Reminder title — `JSONEncoder` will dutifully persist a 10 KB paste.
- DatePicker accepts past dates (`ContactDetailView.swift:123`); `UNCalendarNotificationTrigger` silently drops them.
- `onDelete` swipe (`ContactsListView.swift:28`) wipes contact + reminders permanently with no undo and no confirmation.
- "Delete all data" alert confirms once with no typed-name guard (`SettingsView.swift:28-38`). Acceptable.

### Settings inventory vs. spec
- Subscription / Restore, Appearance, Delete all data, Privacy/Terms/Version — all present.
- **Missing:** notification toggle + time picker for the daily reconnect notification (spec calls it out, no UI exists).
- **Missing:** share/export single contact. v1.1 deferred per spec, but a 10-line `UIActivityViewController` over a markdown blob would meaningfully de-risk the lock-in feeling for a privacy-first CRM.

### Stage 4A surface that bleeds into 3.5
- "Daily reconnect list — 5 people every morning" advertised in paywall (`PricingConfig.swift:21`) but never actually scheduled as a notification. Reviewer who subscribes + waits 24h gets nothing. **2.3.1 accuracy risk.** Flagged here for handoff to Stage 4A.
