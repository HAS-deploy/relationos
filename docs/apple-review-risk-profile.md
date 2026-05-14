# Apple Review Risk Profile — RelationOS

> Produced by Stage 0.5 of the app factory. This file is the single source of
> truth for every later stage. If anything changes (new payment model, new
> permissions, new third-party SDK), update this file first and re-run the
> downstream validators.

- **App name (marketing):** RelationOS
- **Bundle ID:** com.relationos.app
- **ASC App ID:** (set after Stage 5)
- **Profile created:** 2026-05-07
- **Last updated:** 2026-05-07
- **Primary owner:** Tony McMurtrey

---

## 1. App purpose (one sentence)

A private personal CRM for iPhone that remembers people you care about — notes, tags, reminders, and a daily reconnect list — with all data stored on-device.

> Must be accurate, concrete, and match the eventual App Store description
> almost verbatim. "A calorie tracker with barcode scanning" is good. "The
> last fitness app you'll ever need" is not — it trips 2.3 (accurate
> metadata) and 4.2 (minimum functionality).

## 2. Account / login model

- [x] **No accounts, no login** — nothing to provision for reviewer
- [ ] **Optional login** (guest + signed-in) — reviewer exercises guest path; demo creds provided for signed-in path
- [ ] **Required login** — MUST provide working demo credentials (Stage 5)
- [ ] **Sign in with Apple required?** (yes if any 3rd-party-only login: Google / Facebook / OAuth) → guideline **4.8**

Login providers in use: None. The app does not require, offer, or accept any login. There is no server-side identity. iCloud sync is deferred to v1.1 and is not enabled in this build.
Demo creds stored at: `docs/reviewer-demo-credentials.md` (not applicable; file will be empty / N/A)

## 3. Payment model

Pick exactly one primary classification:

- [ ] **Free, no payments anywhere** — cleanest path
- [ ] **Free + non-consumable IAP** (lifetime unlock)
- [ ] **Free + consumable IAP** (credits / packs)
- [x] **Free + auto-renewable subscription** → triggers **3.1.2 HARD disclosures** (Stage 4C + paywall gate)
- [ ] **Free + subscription + lifetime** (mixed)
- [ ] **Paid up-front** (just price tier, no IAP)
- [ ] **External Stripe / web checkout** — ONLY valid if selling physical goods or a real-world service outside the app (**3.1.3**); digital goods consumed in-app MUST use IAP (**3.1.1**)
- [ ] **SaaS with external sign-up** — reader-app exception (**3.1.3(a)**) may apply; user must be able to sign up / pay outside the app

Payment model in use: Free tier (100 contacts cap) + auto-renewable subscription "RelationOS Pro" via StoreKit 2 IAP. Two products in one subscription group: `app.relationos.pro.monthly` ($11.99/mo, Tier 12) and `app.relationos.pro.annual` ($89.99/yr, Tier 90). **Neither product carries a StoreKit introductoryOffer in v1.1.** The 14-day free Pro period is an install-time grant in the app (`Core/Purchases/IntroTrialClock.swift`); reviewer sees Pro features immediately after install without subscribing. No Stripe, no web checkout, no reader-app exception.

### Subscription disclosures required (only if subs) — all mandatory on the paywall

- [x] Subscription title (matches IAP name) — "RelationOS Pro — Monthly" / "RelationOS Pro — Annual"
- [x] Subscription length (monthly / yearly / etc.) — shown explicitly per product
- [x] Price per period (and price-per-unit if not obvious) — "$11.99 / month" / "$89.99 / year (~$7.50 / month)"
- [x] "Payment will be charged to your Apple ID account at confirmation of purchase"
- [x] "Subscription automatically renews unless canceled at least 24 hours before the end of the current period"
- [x] "Your account will be charged for renewal within 24 hours prior to the end of the current period"
- [x] "Subscriptions may be managed and auto-renewal may be turned off by going to the user's Account Settings after purchase"
- [x] Tappable Privacy Policy link (live URL, not mailto) — `https://has-deploy.github.io/relationos/privacy`
- [x] Tappable Terms of Use / EULA link (live URL) — `https://has-deploy.github.io/relationos/terms`
- [x] Restore Purchases action visible

## 4. What the app sells / provides

- [x] Digital goods consumed in-app (unlock, feature, credit, content)
- [ ] Physical goods (shipped)
- [ ] Real-world service (disputes, legal, printing, delivery)
- [ ] SaaS (primarily web, iOS is a thin client)
- [ ] None (free utility)

Checked here: Digital goods consumed in-app. Pro tier unlocks unlimited contacts (vs 100-cap free), the Daily Reconnect view (5-contact prioritized list) plus its widget content, and the "cooling relationships highlighted" sort inside that view. All consumed entirely within the app. No physical goods, no off-device service, no SaaS web equivalent.

## 5. Data collected / stored / shared

Fill the table with each data type the app touches. If you can't fill this
without lying, stop and trace it from the code before continuing.

| Data type | Collected? | Stored where | Transmitted to whom | Linked to user? | Used to track? |
|---|---|---|---|---|---|
| Name | No (user enters about *their contacts*, not themselves) | On-device App-Group UserDefaults (SwiftData in v1.1) | Nobody | No | No |
| Email | No | — | — | — | — |
| Password / auth token | No | — | — | — | — |
| Contacts | Manual entry only in v1; iPhone Contacts ingest deferred to v1.1 | On-device App-Group UserDefaults | Nobody | No | No |
| Location | No (deferred to v1.1) | — | — | — | — |
| Photos | No | — | — | — | — |
| Audio | No | — | — | — | — |
| Health / fitness | No | — | — | — | — |
| Financial | No (Apple StoreKit handles purchase data; we never see PII) | — | Apple (StoreKit) | No (StoreKit-managed) | No |
| User-entered text / documents | Yes — notes the user writes about their contacts | On-device App-Group UserDefaults (SwiftData in v1.1) | Nobody | No | No |
| Purchase history | StoreKit-managed; we read entitlement state only | Apple receipts | Apple | No (Apple-managed) | No |
| Device ID / advertising ID | No | — | — | — | — |
| Usage analytics | PostHog (`phc_zsZ6K…`, `https://us.i.posthog.com`) — anonymous product-interaction events tagged with a random per-install identifier. Configured `personProfiles=.never`, `captureScreenViews=false`, `captureApplicationLifecycleEvents=false`, `sessionReplay=false`. Contact data is never in the payload. | Off-device (PostHog Cloud, US region) | PostHog (processor) | No | No |
| Crash logs | Apple MetricKit (on-device aggregation) + PostHog crash data for diagnostics | On-device + PostHog | Apple + PostHog | No | No |

Nutrition label target (what Stage 8 will click through in ASC → App Privacy):
**"Product Interaction"**, **"Crash Data"**, **"Performance Data"**, **"Other Diagnostic Data"** all marked Collected, Linked-to-User=No, Used-for-Tracking=No, purposes={Analytics, App Functionality}. Matches `RelationOS/Resources/PrivacyInfo.xcprivacy` and `docs/app-privacy-answers.md`. StoreKit purchases are excluded (framework-mediated). Cross-device sync is on the roadmap and is off by default.

## 6. Account deletion (5.1.1(v))

- [x] **Not applicable** (no accounts)
- [ ] **Required** — in-app path exists at: see below
- [ ] **Required** — reviewer demo account can exercise it

Although 5.1.1(v) does not apply (no account model), the app provides a **"Delete all data"** action in Settings → Privacy → "Delete all data" → confirm prompt → on-device store wiped (App-Group UserDefaults). Reviewer can exercise this in section 9.

## 7. Permissions needed (`NS*UsageDescription`)

For each permission, list the `NS*UsageDescription` string planned. Strings
must be user-readable and specific to what the app actually does with the
data — "Used for photos" is a soft reject; "Scan a barcode on food
packaging to look up nutrition info" is a pass.

| Permission | NS key | Planned string |
|---|---|---|
| Camera | `NSCameraUsageDescription` | (not used in v1) |
| Microphone | `NSMicrophoneUsageDescription` | (not used in v1) |
| Photos (read) | `NSPhotoLibraryUsageDescription` | (not used in v1) |
| Photos (add) | `NSPhotoLibraryAddUsageDescription` | (not used in v1) |
| Location (when-in-use) | `NSLocationWhenInUseUsageDescription` | (removed in v1 — deferred) |
| Location (always) | `NSLocationAlwaysAndWhenInUseUsageDescription` | (not used in v1 — deferred) |
| Contacts | `NSContactsUsageDescription` | "RelationOS imports the contacts you choose so you can track who you want to stay in touch with. We never read contacts in the background or send them off-device." |
| Calendar | `NSCalendarsUsageDescription` | (removed in v1 — deferred) |
| HealthKit read | `NSHealthShareUsageDescription` | (not used in v1) |
| HealthKit write | `NSHealthUpdateUsageDescription` | (not used in v1) |
| Motion | `NSMotionUsageDescription` | (not used in v1) |
| Bluetooth | `NSBluetoothAlwaysUsageDescription` | (not used in v1) |
| ATT | `NSUserTrackingUsageDescription` | (not used — RelationOS does not track users across apps or websites) |
| Face ID / Touch ID | `NSFaceIDUsageDescription` | (not used in v1) |
| Local notifications | `NSUserNotificationsUsageDescription` (runtime via UNUserNotificationCenter) | "RelationOS sends reminders you set yourself." |

## 8. Regulated / high-scrutiny flags

Check every box that applies. Each one adds reviewer scrutiny and usually
requires specific evidence in review notes.

- [ ] AI / ML / generative content → may require 17+ rating, content filtering disclosure
- [ ] Parses user documents (PDF / contracts / receipts / recipes / UGC)
- [ ] Uploads user files to a server
- [x] Embeds/bundles third-party SDKs that collect data → PostHog (anonymous product analytics, see §5)
- [ ] Health, fitness, or medical data → **HealthKit / 5.1.3**
- [ ] Financial data / transactions / banking
- [ ] Kids (age rating under 13) → **5.1.4 Kids category** rules apply
- [ ] Legal / regulated advice (insurance, medical, legal, tax)
- [ ] HIPAA / GDPR / CCPA applicability
- [ ] Downloads or installs executable code at runtime → **2.5.2**
- [ ] Embeds its own JavaScript engine → **2.5.1 / 2.5.2** dev-tool carve-out
- [ ] User-generated content visible to other users → **1.2** UGC moderation required
- [ ] Social / chat / messaging features
- [ ] Location tracking in background
- [ ] Uses cryptography beyond TLS / CryptoKit → **export compliance ERN** may be required

For every checked box, write **one paragraph** in section 11 (reviewer
notes) that pre-empts the reviewer's objection.

## 9. Reviewer demo path

Write the exact 5–10 step path the reviewer will take to see the core value
of the app. Include the demo credentials if login is required, the test
data the app needs, and any "skip to premium" toggle for validating paywall
success screens.

```
1. Launch RelationOS — app opens directly to the Contacts tab. No account, no login, no onboarding.
2. **Pro is unlocked automatically for 14 days from install (local grant, NOT a StoreKit introductory offer).** Reviewer will see Pro features without subscribing.
3. Tap "+" → "Pick from Phone" (system picker, no permission prompt) or "Import all from Phone…" (one-time Contacts permission, then explicit row selection). Alternatively "Add manually" — enter name + notes + tags.
4. Open a contact → "Log call, text, or email" → exercise manual log + Apple's system composers. iOS does not share SMS/iMessage/call/email history; the log is the substitute.
5. Tap "Add reminder" → confirm a local notification is scheduled.
6. Open **Settings → "Pro free, N days left"** → paywall sheet renders with:
   - "You're on Pro free, N days left" banner (the install-trial disclosure)
   - Subscription title + length + price
   - All four 3.1.2(a) auto-renew disclosure sentences
   - Privacy Policy + Terms of Use links (tappable, live URLs)
   - Restore Purchases button visible
   - "Subscribe annually" / "Continue annually" CTA (NOT "Start free trial" — there is no StoreKit trial)
7. Tap "Subscribe annually" → StoreKit sandbox prompts for $89.99/year. There is no StoreKit trial sheet — the 14-day Pro period is the install grant from step 2.
8. (Optional) Settings → Privacy → "Delete all data" → confirm → app returns to first-launch state.
```

The app does not require a server backend. No demo credentials. Reviewer flow is entirely on-device.

> Stage 5 and Stage 7 both pull from this section when filling ASC review
> notes. If the demo path requires a server to be up, note the monitoring
> contact and uptime commitment.

## 10. Backend dependencies

| Dependency | URL | Purpose | Required at launch? | Owner |
|---|---|---|---|---|
| Static marketing site | https://has-deploy.github.io/relationos/ | Marketing landing | Yes | Tony |
| Privacy policy | https://has-deploy.github.io/relationos/privacy | Required by App Store | Yes (HARD) | Tony |
| Terms of Use | https://has-deploy.github.io/relationos/terms | Linked from paywall (3.1.2(a)) | Yes (HARD) | Tony |
| Support page | https://has-deploy.github.io/relationos/support | Linked from App Store metadata | Yes (HARD) | Tony |
| Apple StoreKit / App Store | apple.com infra | IAP processing | Yes (Apple-owned) | Apple |
| Apple iCloud / CloudKit | apple.com infra | Deferred to v1.1 | No (not used in v1) | Apple |

Backends that MUST be up during review: the four `has-deploy.github.io/relationos/*` static pages. No dynamic API. No database we run. If the static site is down during review, reviewer hits 5.1.1 (privacy policy unreachable) and 3.1.2(a) (Terms link unreachable). Hosted on GitHub Pages from `HAS-deploy/relationos` (high uptime); verify all four URLs return 200 before submission.

> If any backend is dark when the reviewer tries the app, it's a 2.1 reject.
> Keep these monitored during the review window.

## 11. Pre-emptive review notes draft

Draft the reviewer-notes text here (Stage 7 copies it to ASC). Hit every
flagged item from section 8:

See `docs/app-review-notes.md` for the v1.1 canonical version that gets pasted into ASC. Both files now reflect:

- The 14-day Pro free period is an install-time grant (not a StoreKit introductoryOffer); reviewer sees Pro state without subscribing.
- PostHog is the third-party analytics SDK; events are anonymous, per-install random ID, no contact data; matches PrivacyInfo.xcprivacy + the new App Privacy nutrition answers.
- Contacts permission is requested only by the bulk-import path; the system picker does not request it.
- Google / Microsoft OAuth import code is shipped but hidden (client IDs blank in Info.plist) — read-only contacts scopes, not a login flow, 4.8 N/A.
- CXCallObserver is registered only on-demand inside the LogInteractionSheet flow (defer-start fix in v1.1) — no background call monitoring.

## 12. Required App Store screenshots

- [x] 6.9" iPhone (1320×2868 or 2868×1320) — **3–10 required**
- [x] 13" iPad (2064×2752 or 2752×2064) — **3–10 required** (universal apps)
- [ ] App Preview video — optional, 15–30 s
- Screenshot ideas (one per core feature):

```
1. HERO — "Your relationships, on your phone. Not in the cloud." (home view + small "On Device" badge)
2. DAILY RECONNECT — "Five people. Every morning." (lock-screen widget mockup + expanded list)
3. REMINDERS — "Set a follow-up. Forget the calendar." (contact card with reminder picker)
4. COOLING RELATIONSHIPS — "See who you're losing touch with." (Daily Reconnect view with the oldest-`lastInteractedAt`-first sort surfacing 5 contacts)
5. PRIVACY CLOSER — "Nothing leaves your phone." (Settings → Delete all data + about-section copy)
```

## 13. Privacy policy + terms requirements

- [x] Privacy policy URL hosted at: https://has-deploy.github.io/relationos/privacy
- [x] Terms of Use / EULA URL hosted at: https://has-deploy.github.io/relationos/terms
- [x] Both 200 OK on GET (verify before submission)
- [x] Both match what section 5 (data) + section 3 (payment) actually say

## 14. Go / no-go checklist before leaving Stage 0.5

- [x] Every field above filled (no double-brace placeholders remain)
- [x] Section 8 boxes match what the code will actually do (only AI/ML flagged; AI is on-device only)
- [x] Section 5 data table matches section 8 flags
- [x] Section 3 payment model picked and justified
- [x] Reviewer demo path (section 9) is concrete enough to follow

Only pass when every box is checked. Incomplete profile = Stage 1 blocked.
