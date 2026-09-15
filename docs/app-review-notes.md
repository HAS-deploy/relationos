# App Review Information → Notes — RelationOS

> Paste this (minus the commentary blocks) into
> **App Store Connect → App → Version → App Review Information → Notes**
> when submitting. Keep it to 1,500 chars or less.

---

## What RelationOS does

A personal CRM. Contacts, notes, reminders, and a "five people to reconnect with today" list, all on the iPhone. No account model.

## How to exercise the app in 30 seconds

1. Launch RelationOS — app opens directly to the Contacts tab. No account, no login, no onboarding.
2. **Pro is unlocked automatically for 14 days from install.** You will see Pro features (Daily Reconnect list, unlimited contacts, cooling-relationships highlighting) without ever tapping Subscribe. This is a local install-time grant, NOT an Apple StoreKit introductory offer. After day 14 the app reverts to the free tier.
3. Tap "+" → "Pick from Phone" or "Import all from Phone…" to pull in some contacts (the system picker does not request Contacts permission; bulk import asks once and lets you select rows). Alternatively, "Add manually" — enter a name, notes, tags.
4. Open any contact → tap "Log call, text, or email" → exercise the manual log + Apple's system composers. iOS does not share SMS/iMessage/call history/email content with third-party apps, so this is the substitute and is documented in the in-app footer.
5. Open the contact → tap "Add reminder" → confirm a local notification is scheduled (UNUserNotificationCenter prompt on first reminder).
6. Open **Settings → "Pro free, N days left"** (or **Daily Reconnect** when free) → paywall sheet renders: install-trial banner, subscription title + length + price, all four 3.1.2(a) auto-renew sentences, tappable Privacy Policy and Terms of Use links, and Restore Purchases button.
7. Tap "Subscribe annually" → StoreKit sandbox prompts for $89.99/year. There is no StoreKit trial sheet — the 14-day grant runs from install, not from tapping Subscribe.
8. (Optional) Settings → Privacy → "Delete all data" → confirm → app returns to first-launch state.

## Why each permission prompt appears

**Contacts (`NSContactsUsageDescription`):** Required only by the bulk-import path. The system picker ("Pick from Phone") runs out-of-process under `CNContactPickerViewController` and does NOT request this permission. If granted, the app reads the address book once during the import flow, presents a checkbox list, and the user must tick the rows they actually want imported. RelationOS never reads contacts in the background and never transmits contact data off-device.

**Local Notifications:** Required to deliver the reminders you set yourself. Requested via `UNUserNotificationCenter` when you create your first reminder.

## Pre-emptive notes on flagged items

REGARDING THE 14-DAY INSTALL TRIAL:
On first launch, RelationOS stamps an install date and grants Pro for 14 days. This is a local grant only — it is not an Apple introductory offer, and the StoreKit subscription products carry NO introductoryOffer field. Reviewer will see Pro features unlocked at install. This is intentional and the in-app paywall surfaces a "You're on Pro free, N days left" banner explaining it. The disclosure also appears in the App Description and Terms.

REGARDING DATA / 5.1.1 / App Privacy:
Contacts, notes, reminders, interactions, and tags are stored only on-device (App-Group UserDefaults). RelationOS uses PostHog for anonymous product analytics (install/foreground, explicit `screen.viewed`, paywall views/purchases, feature use). The PostHog SDK is configured with `personProfiles=.never`, `captureScreenViews=false`, `captureApplicationLifecycleEvents=false`, `sessionReplay=false` — we emit those events ourselves. Events leave the device tagged with a random per-install identifier only. No contact data, no IDFA, no name/email. On-device Foundation Models extraction never leaves the device. The PrivacyInfo.xcprivacy manifest declares User ID, Product Interaction, Crash, Performance, and Other Diagnostic Data (all linked=NO, tracking=NO, purpose=Analytics + App Functionality). App Privacy nutrition answers match — do **not** choose "Data Not Collected". The privacy policy linked from the paywall describes the same setup.

REGARDING CONTACT IMPORT FROM EMAIL ACCOUNTS:
"Import from Google" and "Import from Microsoft" menu items exist in the codebase but are HIDDEN in this build — their OAuth client IDs are empty in Info.plist and the menu items are runtime-gated on that. When enabled in a future version, they will use ASWebAuthenticationSession + PKCE to fetch read-only contacts (Google People `contacts.readonly`, Microsoft Graph `Contacts.Read`). They are not a login flow — RelationOS has no user account model — so 4.8 (Sign in with Apple) does not apply.

REGARDING SUBSCRIPTIONS / 3.1.2(a):
The paywall renders all four required auto-renew disclosure sentences verbatim, plus tappable Privacy Policy and Terms of Use links and a visible Restore Purchases action. Both products (`app.relationos.pro.monthly` $11.99/mo, `app.relationos.pro.annual` $89.99/yr) carry NO StoreKit introductoryOffer — the 14-day Pro free period is an install-time grant in the app code (see paragraph above).

## Demo credentials

Not applicable — no account model. The app works from the first launch.

## Known limitations we want to acknowledge

v1.1 is iPhone + iPad only (no Android, no Mac, no Apple Watch). Cross-device sync is on the roadmap. Email account import (Google / Microsoft) is implemented but hidden in this build — OAuth client IDs are empty.

## Contact during review

- Name: Tony McMurtrey
- Email: tony@medbillresolve.com
- Phone: +12102106034

---

_Last edited: 2026-05-14_
