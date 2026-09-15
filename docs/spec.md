# RelationOS — Product Spec

> Source: locked outputs of the 2026-05-06 competitive + pricing analysis, signed off by user.
> This file is the **inline brief** for the App Factory flow. It supersedes the original analysis prompt.
> Original analysis prompt + comparison findings live alongside in `docs/analysis-findings.md`.

---

## 1. One-sentence purpose

A private personal CRM that lives entirely on the user's iPhone — no account required, no contacts uploaded, no data leaves the device.

## 2. Category + positioning

- **App Store primary category:** Productivity
- **App Store secondary category:** Lifestyle
- **Positioning frame:** a Hippo-style on-device personal CRM — your relationships, your phone, no cloud.
- **Lead message (locked):** privacy / on-device / memory. **NOT AI.** v1 ships no AI features.

## 3. Platforms (v1)

- iOS 16+ (iPhone)
- iPad universal — yes (same SwiftUI codebase)
- watchOS — no (not v1)
- macOS Catalyst — no (not v1)
- Android — no

## 4. Account / login model

- **No account required.** No email, no password, no SSO.
- iCloud sync (CloudKit) is deferred to v1.1 — v1 ships device-only.
- Sign in with Apple: N/A (no third-party login is offered).

## 5. Payment / monetization

- **StoreKit 2 auto-renewable subscriptions** (no Stripe, no web purchase, no reader-app exception needed — purely digital content unlocked in-app).
- **Free tier:** up to **100 contacts**, basic notes + reminders. Intelligence/AI features paywalled.
- **Pro Monthly:** $11.99 / month — Tier 12. No StoreKit introductoryOffer (v1.1 dropped them).
- **Pro Annual:** $89.99 / year — Tier 90. No StoreKit introductoryOffer.
- Trial: **14 days of Pro granted at install** via `Core/Purchases/IntroTrialClock` (App Group UserDefaults stamp). Runs once per device install, not per Apple ID. Paywall default toggle = annual.
- Subscription group: `RelationOS Pro` (one group, both products).
- No lifetime SKU at v1 (revisit at month 6 if user demand surfaces).

## 6. Feature scope (v1)

### Core (free + paid)
- Contact creation (manual or from on-device Contacts via user-permission EventKit/Contacts read)
- Notes per contact (rich text, on-device only)
- Tags / groups
- Interaction history timestamps (manually logged)
- Reminders (calendar-style, local notifications only)

### Pro-tier paywall unlocks
- **Unlimited contacts** (free tier capped at 100)
- **Daily reconnect list** — 5 contacts to re-engage with each morning, surfaced in widget + notification
- **Cooling relationships highlighted** — the existing oldest-`lastInteractedAt`-first sort, prioritizing contacts you haven't talked to in a while inside the Daily Reconnect view
- **Reminders** (premium-tier reminders): the free tier ships local-notification reminders capped at the free contact count; Pro reminders ride alongside the unlimited-contact uplift (same `ReminderManager.swift` / `UNNotificationCenter`, no "smart" / context-aware logic in v1)

### iOS-native polish (free + paid)
- Widgets (small, medium, lock-screen `accessoryRectangular`) — show daily reconnect or next reminder
- Dynamic Type support throughout

## 7. Data, privacy, permissions

- **All user data on-device.** UserDefaults / App-Group store in v1; SwiftData migration in v1.1. No data is transmitted off device.
- **No third-party analytics SDKs in v1.** Optional crash reporting via Apple's MetricKit (on-device aggregation only).
- **No AI / ML features in v1.** AI meeting notes and semantic search are deferred to v1.1 and are not advertised in this submission.
- **Permissions requested (with planned `NS*UsageDescription` strings):**
  - `NSUserNotificationsUsageDescription` (runtime via `UNUserNotificationCenter`) — "RelationOS sends reminders you set yourself."
  - Contacts / Calendar / Location permission strings are **removed in v1** — the underlying ingest features ship in v1.1.
- **Account deletion:** trivial — user can wipe all data via Settings → "Delete all data" → confirm → SwiftData stack rebuilt empty. Required for 5.1.1(v).
- **Privacy nutrition label answer (App Privacy, v1 draft):** historically "no data collected". **v1.1.3 SoT:** PostHog is wired — choose **Yes, we collect data** (User ID + Product Interaction + Crash / Performance / Other Diagnostic). See `docs/app-privacy-answers.md`. Do not answer "Data Not Collected".

## 8. App Store metadata (locked)

- **App name:** `RelationOS`
- **Subtitle (28 chars):** `Personal CRM. On your phone.`
- **Promotional text (170):** "Remember everyone who matters. A daily reconnect list and reminders — all on your iPhone. Nothing leaves your device unless you say so."
- **Keywords (99 chars):** `personal crm,relationship,contacts,reminders,follow up,network,private,offline,memory,reconnect`
- **Description body:** see `docs/metadata.md` (Stage 1.5 output).
- **Age rating:** 4+
- **Marketing URL:** `https://has-deploy.github.io/relationos/`
- **Support URL:** `https://has-deploy.github.io/relationos/support`
- **Privacy policy URL:** `https://has-deploy.github.io/relationos/privacy`

## 9. App Store screenshots (5 panels — locked concept)

1. HERO — "Your relationships, on your phone. Not in the cloud."
2. DAILY RECONNECT — "Five people. Every morning."
3. REMINDERS — "Set a follow-up. Forget the calendar."
4. COOLING RELATIONSHIPS — "See who you're losing touch with."
5. PRIVACY CLOSER — "Nothing leaves your phone unless you say so."

## 10. Launch checklist anchors

- Hosting: GitHub Pages on `HAS-deploy/relationos` (root pages at `https://has-deploy.github.io/relationos/`).
- GitHub: `HAS-deploy/relationos`.
- TestFlight: 10–20 beta testers before public submission.
- StoreKit sandbox tests: paywall opens, trial starts, mid-trial cancel = no charge, restore works, both products listed correctly.
- Free-tier 100-contact cap enforced before paywall fires.

## 11. What NOT to ship in v1 (overbuild candidates from analysis)

- Email / calendar / LinkedIn ingest (intentionally out — local-first does not pull cloud feeds).
- Android.
- Team / sharing / multi-seat.
- Any AI feature that would require off-device inference.
- Lifetime SKU (revisit at 6-month mark).
- Relationship "scoring" as a top-level number — replace with "cadence health" (simpler, more honest, ships).
- **AI meeting notes** — deferred to v1.1 (see audit findings 2026-05-07). Not in v1 paywall, not advertised in metadata.
- **Semantic search** — deferred to v1.1 (see audit findings 2026-05-07). Not in v1 paywall, not advertised in metadata.
- **iCloud sync (CloudKit)** — deferred to v1.1. v1 description explicitly says "Cloud sync is on the v1.1 roadmap."
- **App Intents / Shortcuts** — deferred to v1.1. Not advertised in v1 metadata.
- **Smart / context-aware reminders** — deferred to v1.1. v1 ships plain `UNNotificationCenter` reminders only; do not advertise as "smart."
- **Export everything** — deferred to v1.1. Not in v1 metadata.

---

## Source

Original product hypothesis + full competitive + pricing analysis: see `docs/analysis-findings.md` (the deduplicated analysis output dated 2026-05-06, with locked decisions: Base scenario, 100-contact free cap, AI as supporting message, both monthly and annual offered).
