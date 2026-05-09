# App Review Information → Notes — RelationOS

> Paste this (minus the commentary blocks) into
> **App Store Connect → App → Version → App Review Information → Notes**
> when submitting. Keep it to 1,500 chars or less.
>
> This file is regenerated from `docs/apple-review-risk-profile.md`
> section 8 (flags) and section 11 (reviewer-notes draft). If the risk
> profile changes, re-scaffold this file or edit in place to match.

---

## What RelationOS does

A private personal CRM that runs entirely on your phone.

## How to exercise the app in 30 seconds

1. Launch RelationOS — app opens directly to the Contacts tab. No account creation, no login, no onboarding.
2. Tap "+" → enter "John Doe", notes "investor at Acme Ventures", tags "VC". Save.
3. Open the contact, tap "Add reminder" → "Follow up in 2 weeks". Confirm a local notification is scheduled.
4. Repeat steps 2-3 with 2-3 more contacts to populate the daily reconnect list.
5. Tap the **Daily Reconnect** tab, or open **Settings → "Try RelationOS Pro"**. Paywall sheet renders with subscription title + length + price, all four 3.1.2(a) auto-renew sentences, tappable Privacy Policy and Terms of Use links, and Restore Purchases button.
6. Tap "Start 14-day free trial" → StoreKit sandbox sheet presents the 2-week trial.
7. (Optional) Settings → Privacy → "Delete all data" → confirm → app returns to first-launch state.

## Why each permission prompt appears

**Local Notifications:** Required to deliver the reminders you set yourself. Requested at runtime via `UNUserNotificationCenter` when you create your first reminder.
<!--
  One short paragraph per permission in section 7 of the risk profile.
  Copy the NS*UsageDescription text verbatim and add a sentence of context
  the reviewer couldn't derive from the string alone.
-->

## Pre-emptive notes on flagged items

RelationOS is a private, on-device personal CRM. Reviewer can exercise the full app without creating an account.

REGARDING AI / ML:
v1 ships no AI features. AI meeting notes and semantic search are on the v1.1 roadmap and are not advertised in this submission. No data is sent to any third-party LLM. No data leaves the device.

REGARDING DATA / 5.1.1 / App Privacy:
RelationOS collects no data. All user data lives in App-Group UserDefaults on-device. iCloud sync is deferred to v1.1 and is not enabled in this build. The App Privacy nutrition label is "The developer does not collect any data from this app."

REGARDING SUBSCRIPTIONS / 3.1.2(a):
The paywall renders all four required auto-renew disclosure sentences verbatim, plus tappable Privacy Policy and Terms of Use links and a visible Restore Purchases action. Both products (`app.relationos.pro.monthly` $11.99, `app.relationos.pro.annual` $89.99) offer a 2-week introductory free trial.
<!--
  For every box checked in section 8 of the risk profile, one paragraph:
  name the concern, cite the guideline number, explain why we comply, point
  to specific evidence in the app.

  Examples:

  AI content (17+):
  "RelationOS uses OpenAI's text API to summarize user-uploaded
  contracts. Per 4.0 design + 1.1 safety, the app rates at 17+; content is
  generated from user uploads only, not open-ended prompts; output is
  shown read-only."

  Document parsing (2.1 completeness):
  "Every parser path has error, empty, and partial-input handling — see
  Parser.parseIngredientLine covering 10+ malformed cases in
  ParserTests.swift. No crash path, no placeholder UI."

  Reader-app exception (3.1.3(a)):
  "RelationOS signs into RelationOS via web OAuth; we do not sell or
  unlock content inside the app. All payment happens on RelationOS's
  web property. Users can still use the app's local features without an
  account."
-->

## Demo credentials

Not applicable — no account model.
<!--
  If login is required, paste the demo creds from
  docs/reviewer-demo-credentials.md. If no accounts, say "No login
  required — the app works from the first launch."
-->

## Known limitations we want to acknowledge

v1 is iPhone + iPad only (no Android, no Mac, no Apple Watch). Email, calendar, and LinkedIn ingest are intentionally not supported in v1 — RelationOS does not pull from cloud services.
<!--
  Small but non-guideline-breaking things worth pre-empting:
  - "iPad landscape-only: we split to phone/pad assets in a future update"
  - "No macOS support yet"
  - "Analytics: we use Apple App Analytics only; no third-party tracking"
-->

## Contact during review

- Name: Tony McMurtrey
- Email: tony@medbillresolve.com
- Phone: +12102106034

---

_Last edited: 2026-05-07_
